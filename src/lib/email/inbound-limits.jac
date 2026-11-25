# Column budgets that hold on D1 (2 MB rows), MySQL varchar keys and PostgreSQL btree entries.
glob INBOUND_LIMITS: any = record({
    "textBodyBytes": 450_000,
    "htmlBodyBytes": 900_000,
    "messageIdChars": 512,
    "subjectChars": 998,
    "addressChars": 998,
    "addressListChars": 8_000,
    "referencesCount": 20,
});

glob:priv encoder: any = new(globalThis.TextEncoder),
          decoder: any = new(globalThis.TextDecoder, "utf-8", record({"fatal": False})),
          REPLACEMENT_TAIL: any = rx("�+$", "u");

def truncateUtf8(value: any, maxBytes: int) -> str {
    # UTF-8 needs at most 4 bytes a character, so anything shorter than a quarter always fits.
    if value.length * 4 <= maxBytes {
        return value;
    }
    encoded = encoder.encode(value);
    if encoded.byteLength <= maxBytes {
        return value;
    }
    # A cut inside a multi-byte sequence decodes to a replacement character; drop it.
    return rx_sub(decoder.decode(encoded.subarray(0, maxBytes)), REPLACEMENT_TAIL, "");
}

"""Truncate to `max` UTF-16 units without leaving half of a surrogate pair at the end."""
def capChars(value: any, limit: int) -> any {
    if not value or value.length <= limit {
        return value;
    }
    last = value.charCodeAt(limit - 1);
    return value.slice(0, limit - 1 if 0xd800 <= last <= 0xdbff else limit);
}

def:priv bounded_id(value: any) -> any {
    return value if value and value.length <= INBOUND_LIMITS.messageIdChars else NULL;
}

def:priv bounded_body(value: any, max_bytes: int) -> any {
    return NULL if value is NULL else truncateUtf8(value, max_bytes);
}

"""Keep every stored field inside what all three databases accept.

A hostile or merely odd message is then stored (the full original stays in raw MIME) instead of
failing the insert and being retried until it is dropped.
"""
def boundParsedEmail(parsed: any) -> any {
    lim = INBOUND_LIMITS;
    return merged(
        parsed,
        {
            "subject": capChars(parsed.subject, lim.subjectChars),
            "text": bounded_body(parsed.text, lim.textBodyBytes),
            "html": bounded_body(parsed.html, lim.htmlBodyBytes),
            "messageId": bounded_id(parsed.messageId),
            "fromAddr": capChars(parsed.fromAddr, lim.addressChars),
            "toAddr": capChars(parsed.toAddr, lim.addressListChars),
            "ccAddr": capChars(parsed.ccAddr, lim.addressListChars),
            "bccAddr": capChars(parsed.bccAddr, lim.addressListChars),
            "replyTo": capChars(parsed.replyTo, lim.addressListChars),
            "inReplyTo": bounded_id(parsed.inReplyTo),
            "references": [
                r
                for r in parsed.references
                if r.length <= lim.messageIdChars
            ][-lim.referencesCount:],
        },
    );
}
