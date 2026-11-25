# Column budgets that hold on D1 (2 MB rows), MySQL varchar keys and PostgreSQL btree entries.
glob INBOUND_LIMITS: any = record({k: int(v) for (k, _, v) in [p.partition("=") for p in """
    textBodyBytes=450000 htmlBodyBytes=900000 messageIdChars=512 subjectChars=998 addressChars=998
    addressListChars=8000 referencesCount=20""".split()]});

def truncateUtf8(value: any, maxBytes: int) -> str {
    # UTF-8 needs at most 4 bytes a character, so anything shorter than a quarter always fits.
    encoded = None if value.length * 4 <= maxBytes else new(globalThis.TextEncoder).encode(value);
    if encoded is None or encoded.byteLength <= maxBytes {
        return value;
    }
    # A cut inside a multi-byte sequence decodes to a replacement character; drop it.
    cut = new(globalThis.TextDecoder).decode(encoded.subarray(0, maxBytes));
    return rx_sub(cut, rx("�+$", "u"), "");
}

# Truncate to `max` UTF-16 units without leaving half of a surrogate pair at the end.
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

# Keep every stored field inside what all three databases accept, so a hostile or merely odd
# message is stored (the full original stays in raw MIME) instead of failing the insert and being
# retried until it is dropped.
def boundParsedEmail(parsed: any) -> any {
    lim = INBOUND_LIMITS;
    n = lim.addressListChars;
    lists = {k: capChars(parsed[k], n) for k in "toAddr ccAddr bccAddr replyTo".split()};
    refs = [r for r in parsed.references if r.length <= lim.messageIdChars];
    bounded = {
        "subject": capChars(parsed.subject, lim.subjectChars),
        "text": bounded_body(parsed.text, lim.textBodyBytes),
        "html": bounded_body(parsed.html, lim.htmlBodyBytes),
        "messageId": bounded_id(parsed.messageId),
        "fromAddr": capChars(parsed.fromAddr, lim.addressChars),
        "inReplyTo": bounded_id(parsed.inReplyTo),
        "references": refs[-lim.referencesCount:],
    };
    return merged(parsed, lists, bounded);
}
