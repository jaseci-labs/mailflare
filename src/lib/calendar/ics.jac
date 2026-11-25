"""Shared iCalendar (RFC 5545) writing helpers for the feed, outgoing invitations and invitation replies."""

# Longest mailbox allowed by RFC 5321 (254 in practice); anything longer is never tested or written.
glob MAX_ICS_ADDRESS: int = 320;

# The local part excludes @ so a long run of @ cannot backtrack quadratically.
glob:priv ADDRESS: any = rx(r'^[^\s<>",;:@]+@[^\s<>",;:@]+$'),
          CONTROL: any = rx(r"[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]", "g"),
          SPECIAL: any = rx(r"[\\;,]", "g"),
          LINE_BREAK: any = rx(r"\r\n|\r|\n", "g"),
          ENCODER: any = new(globalThis.TextEncoder);

"""A calendar address must be one plain mailbox; the length is capped before the pattern is tried."""
def isIcsAddress(value: str) -> bool {
    return len(value) <= MAX_ICS_ADDRESS and ADDRESS.test(value);
}

"""
Control characters other than tab and line breaks are dropped, and every line-break form becomes the \\n escape:
a bare CR left in the output would let event text start a new property line.
"""
def escapeIcsText(value: str) -> str {
    return rx_sub(rx_sub(rx_sub(value, CONTROL, ""), SPECIAL, "\\$&"), LINE_BREAK, "\\n");
}

"""RFC 5545 section 3.1: lines over 75 octets are folded with CRLF + space, on code point boundaries."""
def foldIcsLine(line: str) -> str {
    if ENCODER.encode(line).length <= 75 {
        return line;
    }
    parts: list[str] = [];
    (current, size, limit) = ("", 0, 75);
    for ch in globalThis.Array.from(line) {
        width: int = ENCODER.encode(ch).length;
        if size + width > limit {
            parts.append(current);
            (current, size, limit) = ("", 0, 74);
        }
        current += ch;
        size += width;
    }
    parts.append(current);
    return "\r\n ".join(parts);
}

"""A UTC DATE-TIME value such as 20261104T170000Z."""
def formatIcsUtc(value: any) -> str {
    return rx_sub(value.toISOString(), rx(r"[-:]|\.\d{3}", "g"), "");
}

"""Folds every line and joins them with CRLF, ending with the trailing CRLF the RFC requires."""
def joinIcsLines(lines: list[str]) -> str {
    return "\r\n".join([foldIcsLine(line) for line in lines]) + "\r\n";
}
