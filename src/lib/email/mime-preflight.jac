# Cheap, linear raw-byte scan that rejects MIME shapes known to make the parser burn CPU or memory
# (header, part, nesting and line floods). Runs before any decode: one pass over the bytes.
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

def:priv spells(view: any, pos: int, word: any) -> bool {
    for j in range(word.length) {
        if (view[pos + j] | 0x20) != word.charCodeAt(j) {
            return False;
        }
    }
    return True;
}

# True when line `start`..`end` begins with the ASCII `name` (any case) and holds `needle` in its
# first 256 bytes.
def:priv header_has(view: any, start: int, end: int, name: any, needle: any) -> bool {
    if end - start < name.length or not spells(view, start, name) {
        return False;
    }
    limit = globalThis.Math.min(end, start + 256) - needle.length;
    return any(spells(view, i, needle) for i in range(start, limit + 1));
}

def mimePreflightReason(raw: any) -> any {
    view = raw if isinstance(raw, globalThis.Uint8Array) else new(globalThis.Uint8Array, raw);
    (size, start) = (view.length, 0);
    (boundaries, nested, text_lines, header_ended) = (0, 0, 0, False);
    # The current part's header block and transfer encoding tell base64 from text lines.
    (in_part_headers, part_is_base64) = (True, False);
    while start < size {
        end: int = view.indexOf(10, start);  # \n
        end = size if end == -1 else end;
        cend = end - 1 if end > start and view[end - 1] == 13 else end;  # without the \r
        if cend == start {
            (header_ended, in_part_headers) = (True, False);
        } elif not header_ended and end > MIME_LIMITS.maxHeaderBytes {
            return "Message rejected: header block exceeds 64 KiB.";
        } elif cend - start > 2 and view[start] == 45 and view[start + 1] == 45 {  # --boundary
            if (boundaries := boundaries + 1) > MIME_LIMITS.maxBoundaryLines {
                return "Message rejected: too many MIME parts.";
            }
            (in_part_headers, part_is_base64, start) = (True, False, end + 1);
            continue;
        } else {
            # Not limited to part headers: a nested message restarts its own header block.
            if header_has(view, start, cend, "content-type:", "message/rfc822") {
                if (nested := nested + 1) > MIME_LIMITS.maxNestedMessages {
                    return "Message rejected: too many nested messages.";
                }
            }
            if in_part_headers
                and header_has(view, start, cend, "content-transfer-encoding:", "base64")
            {
                part_is_base64 = True;
            }
        }
        if not in_part_headers and not part_is_base64 {
            if (text_lines := text_lines + 1) > MIME_LIMITS.maxTextLines {
                return "Message rejected: malformed MIME structure (too many lines).";
            }
        }
        start = end + 1;
    }
    return NULL;
}
