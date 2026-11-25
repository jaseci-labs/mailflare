"""What SNS posts: Type, MessageId, TopicArn, Message, Subject, Timestamp, SubscribeURL, Token, signature fields."""
type SnsEnvelope = any;

"""`o?.a?.b`: undefined once a link is missing, else the value as it is (null included)."""
def:priv dig(o: any, *path: str) -> any {
    for key in path {
        if nil(o) {
            return None;
        }
        o = getattr(o, key, None);
    }
    return o;
}

"""Reads the JSON an SES S3 receipt action publishes to SNS; null for anything else."""
def parseSesNotification(message: str) -> any {
    try {
        parsed = globalThis.JSON.parse(message);
    } except Exception {
        return NULL;
    }
    if parsed is NULL {
        raise new(globalThis.TypeError, "Cannot read properties of null (reading 'receipt')");
    }
    (mail, receipt) = (dig(parsed, "mail"), dig(parsed, "receipt"));
    action = dig(receipt, "action");
    if dig(parsed, "notificationType") != "Received"
        or dig(action, "type") != "S3"
        or not dig(action, "bucketName")
        or not dig(action, "objectKey")
    {
        return NULL;
    }
    # Repeated headers keep their first (topmost) value: that is the hop nearest to us, the one a sender cannot forge.
    headers: any = globalThis.Object();
    for header in either(dig(mail, "headers"), []) {
        name = header.name.toLowerCase();
        if not globalThis.Reflect.has(headers, name) {
            headers[name] = header.value;
        }
    }
    verdict = lambda (kind: str) -> any { dig(receipt, kind, "status") };
    return merged({
        "from": either(dig(mail, "source"), ""),
        "recipients": either(dig(receipt, "recipients"), either(dig(mail, "destination"), [])),
        "bucket": action.bucketName,
        "key": action.objectKey,
        "virusFailed": verdict("virusVerdict") == "FAIL",
        # Undefined when SES cut the list short, so the caller reads the headers from the raw message.
        "headers": None if dig(mail, "headersTruncated") else headers,
        "verdicts": merged({
            "spf": verdict("spfVerdict"),
            "dkim": verdict("dkimVerdict"),
            "dmarc": verdict("dmarcVerdict"),
            "spam": verdict("spamVerdict"),
            "virus": verdict("virusVerdict"),
        }),
    });
}

"""Compares every character whatever the first difference, so timing tells nothing."""
def safeEqual(a: any, b: any) -> bool {
    if a.length != b.length {
        return False;
    }
    diff = 0;
    for index in range(a.length) {
        diff |= a.charCodeAt(index) ^ b.charCodeAt(index);
    }
    return diff == 0;
}
