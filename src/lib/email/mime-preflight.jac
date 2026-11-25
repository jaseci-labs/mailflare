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

# The limits the line loop reads, as ints so its comparisons stay plain.
glob:priv MAX_HEADER_BYTES: int = 64 * 1024,
          MAX_BOUNDARY_LINES: int = 1_000,
          MAX_NESTED_MESSAGES: int = 20,
          MAX_TEXT_LINES: int = 40_000;

# The byte at `pos`; callers stay inside the view. A direct read: `view[pos]` dispatches per call.
def:priv byte_at(view: bytes, pos: int) -> int {
    b: int = globalThis.Reflect.get(view, pos);
    return b;
}

# Where a non-empty line ending at `end` stops without its \r.
def:priv content_end(view: bytes, end: int) -> int {
    return end - 1 if byte_at(view, end - 1) == 13 else end;
}

# True when the bytes from `pos` spell the lower-case ASCII `word` in any case
# (`(byte | 0x20) == char`, as the scan has always compared).
def:priv spells(view: bytes, pos: int, word: str) -> bool {
    n: int = len(word);
    j: int = 0;
    while j < n {
        b: int = globalThis.Reflect.get(view, pos + j);
        c: int = globalThis.String.prototype.charCodeAt.call(word, j);
        if (b | 0x20) != c {
            return False;
        }
        j += 1;
    }
    return True;
}

# True when line `start`..`end` begins with the ASCII `name` (any case) and holds `needle` in its
# first 256 bytes.
def:priv header_has(view: bytes, start: int, end: int, name: str, needle: str) -> bool {
    if end - start < len(name) or not spells(view, start, name) {
        return False;
    }
    limit: int = min(end, start + 256) - len(needle);
    i: int = start;
    while i <= limit {
        if spells(view, i, needle) {
            return True;
        }
        i += 1;
    }
    return False;
}

def mimePreflightReason(raw: any) -> any {
    view: bytes = raw
        if isinstance(raw, globalThis.Uint8Array)
        else new(globalThis.Uint8Array, raw);
    size: int = len(view);
    start: int = 0;
    boundaries: int = 0;
    nested: int = 0;
    text_lines: int = 0;
    header_ended = False;
    # The current part's header block and transfer encoding tell base64 from text lines.
    in_part_headers = True;
    part_is_base64 = False;
    while start < size {
        end: int = globalThis.Uint8Array.prototype.indexOf.call(view, 10, start);  # \n
        if end == -1 {
            end = size;
        }
        # The line is empty when it is nothing or a lone \r. Otherwise its first byte says what it
        # can be, and only a boundary or a header needs its end without the \r.
        first: int = byte_at(view, start);
        if first == 10 or (first == 13 and end == start + 1) {
            header_ended = True;
            in_part_headers = False;
        } elif not header_ended and end > MAX_HEADER_BYTES {
            return "Message rejected: header block exceeds 64 KiB.";
        } elif first == 45
            and end - start > 2
            and byte_at(view, start + 1) == 45
            and content_end(view, end) - start > 2
        {
            # --boundary
            boundaries += 1;
            if boundaries > MAX_BOUNDARY_LINES {
                return "Message rejected: too many MIME parts.";
            }
            in_part_headers = True;
            part_is_base64 = False;
            start = end + 1;
            continue;
        } elif (first | 0x20) == 99 {
            # Only a line starting with c or C can be either header below.
            # Not limited to part headers: a nested message restarts its own header block.
            cend: int = content_end(view, end);
            if header_has(view, start, cend, "content-type:", "message/rfc822") {
                nested += 1;
                if nested > MAX_NESTED_MESSAGES {
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
            text_lines += 1;
            if text_lines > MAX_TEXT_LINES {
                return "Message rejected: malformed MIME structure (too many lines).";
            }
        }
        start = end + 1;
    }
    return NULL;
}
