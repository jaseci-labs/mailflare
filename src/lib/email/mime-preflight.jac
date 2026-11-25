"""Cheap, linear raw-byte scan that rejects MIME shapes known to make the parser burn CPU or memory.

Header floods, thousands of parts, endless nested message/rfc822, line floods in text parts. It
runs before any decode, so a hostile message costs one pass over the bytes.
"""
glob MIME_LIMITS: any = record({
    "maxHeaderBytes": 64 * 1024,
    # postal-mime 4 sums header bytes over every part (at least 64 per line); the top-level
    # header is capped by maxHeaderBytes above.
    "maxParsedHeaderBytes": 2 * 1024 * 1024,
    "maxBoundaryLines": 1_000,
    "maxNestedMessages": 20,
    # Lines outside base64 parts: postal-mime spends memory per line there, so 262k lines of
    # any length exhaust a 128 MB heap. Base64 attachment lines are chunked and stay cheap.
    "maxTextLines": 40_000,
    "maxNestingDepth": 20,
});

glob:priv NEWLINE: int = 10,
          CARRIAGE_RETURN: int = 13,
          DASH: int = 45;

"""True when the bytes at `pos` spell the lower-case ASCII `word`, whatever their case."""
def:priv spells(view: any, pos: int, word: any) -> bool {
    for j in range(word.length) {
        if (view[pos + j] | 0x20) != word.charCodeAt(j) {
            return False;
        }
    }
    return True;
}

def:priv line_starts(view: any, start: int, end: int, prefix: any) -> bool {
    return end - start >= prefix.length and spells(view, start, prefix);
}

"""Looks for `needle` in the first 256 bytes of a line."""
def:priv line_contains(view: any, start: int, end: int, needle: any) -> bool {
    limit = globalThis.Math.min(end, start + 256) - needle.length;
    for i in range(start, limit + 1) {
        if spells(view, i, needle) {
            return True;
        }
    }
    return False;
}

def mimePreflightReason(raw: any) -> any {
    view = raw if isinstance(raw, globalThis.Uint8Array) else new(globalThis.Uint8Array, raw);
    size: int = view.length;
    (boundary_lines, nested_messages, text_lines) = (0, 0, 0);
    header_ended = False;
    # The current part's header block and transfer encoding tell base64 from text lines.
    (in_part_headers, part_is_base64) = (True, False);
    line_start = 0;
    while line_start < size {
        line_end: int = view.indexOf(NEWLINE, line_start);
        if line_end == -1 {
            line_end = size;
        }
        content_end = line_end;
        if content_end > line_start and view[content_end - 1] == CARRIAGE_RETURN {
            content_end -= 1;
        }
        if content_end == line_start {
            header_ended = True;
            in_part_headers = False;
        } elif not header_ended and line_end > MIME_LIMITS.maxHeaderBytes {
            return "Message rejected: header block exceeds 64 KiB.";
        } elif content_end - line_start > 2
            and view[line_start] == DASH
            and view[line_start + 1] == DASH
        {
            boundary_lines += 1;
            if boundary_lines > MIME_LIMITS.maxBoundaryLines {
                return "Message rejected: too many MIME parts.";
            }
            (in_part_headers, part_is_base64) = (True, False);
            line_start = line_end + 1;
            continue;
        } else {
            # Not limited to part headers: a nested message restarts its own header block.
            if line_starts(view, line_start, content_end, "content-type:")
                and line_contains(view, line_start, content_end, "message/rfc822")
            {
                nested_messages += 1;
                if nested_messages > MIME_LIMITS.maxNestedMessages {
                    return "Message rejected: too many nested messages.";
                }
            }
            if in_part_headers
                and line_starts(view, line_start, content_end, "content-transfer-encoding:")
                and line_contains(view, line_start, content_end, "base64")
            {
                part_is_base64 = True;
            }
        }
        if not in_part_headers and not part_is_base64 {
            text_lines += 1;
            if text_lines > MIME_LIMITS.maxTextLines {
                return "Message rejected: malformed MIME structure (too many lines).";
            }
        }
        line_start = line_end + 1;
    }
    return NULL;
}
