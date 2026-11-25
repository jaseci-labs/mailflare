"""Compares two strings without stopping at the first difference."""
def:priv same_text(a: any, b: any) -> bool {
    if a.length != b.length {
        return False;
    }
    diff = 0;
    for i in range(a.length) {
        diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
    }
    return diff == 0;
}

"""Verifies a Svix-signed webhook (what Resend sends).

HMAC-SHA256 over `${id}.${timestamp}.${body}` with the base64 secret after the `whsec_` prefix,
compared against every `v1,<base64>` entry in the signature header.
"""
async def verifySvixSignature(
    secret: str, headers: any, body: str, toleranceSeconds: any = None, now: any = None
) -> bool {
    (mid, timestamp, signature) = (
        at(headers, "id"),
        at(headers, "timestamp"),
        at(headers, "signature"),
    );
    if not (mid and timestamp and signature) {
        return False;
    }
    tolerance = 5 * 60 if toleranceSeconds is None else toleranceSeconds;
    moment = globalThis.Date.now() if now is None else now;
    seconds = globalThis.Number(timestamp);
    if not globalThis.Number.isFinite(seconds)
        or globalThis.Math.abs(moment / 1000 - seconds) > tolerance
    {
        return False;
    }
    try {
        key_bytes = globalThis.Uint8Array.from(
            globalThis.atob(secret.removeprefix("whsec_")),
            lambda (ch: any) -> any { ch.charCodeAt(0) },
        );
    } except Exception {
        return False;
    }
    subtle = globalThis.crypto.subtle;
    key = await subtle.importKey(
        "raw", key_bytes, record({"name": "HMAC", "hash": "SHA-256"}), False, ["sign"]
    );
    signed = await subtle.sign(
        "HMAC", key, new(globalThis.TextEncoder).encode(f"{mid}.{timestamp}.{body}")
    );
    expected = globalThis.btoa(
        globalThis.String.fromCharCode.apply(NULL, new(globalThis.Uint8Array, signed))
    );
    for item in signature.split(" ") {
        parts = item.split(",");
        if len(parts) > 1 and parts[0] == "v1" and parts[1] and same_text(parts[1], expected) {
            return True;
        }
    }
    return False;
}
