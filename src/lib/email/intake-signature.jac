glob INBOUND_SIGNATURE_MAX_AGE_SECONDS: int = 300;

"""Hex HMAC-SHA256 of `prefix` followed by the raw body."""
async def:priv hmac_hex(secret: str, prefix: str, raw: any) -> str {
    encoder = new(globalThis.TextEncoder);
    subtle = globalThis.crypto.subtle;
    key = await subtle.importKey(
        "raw", encoder.encode(secret), record({"name": "HMAC", "hash": "SHA-256"}), False, ["sign"]
    );
    head = encoder.encode(prefix);
    data = new(globalThis.Uint8Array, head.byteLength + raw.byteLength);
    data.set(head, 0);
    data.set(new(globalThis.Uint8Array, raw), head.byteLength);
    return globalThis.Array.prototype.map.call(
        new(globalThis.Uint8Array, await subtle.sign("HMAC", key, data)),
        lambda (b: any) -> any { b.toString(16).padStart(2, "0") },
    ).join("");
}

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

"""HMAC-SHA256 over `from\nto\n` + raw body, hex encoded. Shared with the relay Worker."""
async def signInbound(secret: str, raw: any, sender: str, to: str) -> str {
    return await hmac_hex(secret, f"{sender}\n{to}\n", raw);
}

async def verifyInboundSignature(
    secret: str, signature: str, raw: any, sender: str, to: str
) -> bool {
    return same_text(await signInbound(secret, raw, sender, to), signature);
}

"""Version 2 also covers the header map and a Unix timestamp (seconds).

Neither can then be altered in transit, and a captured request stops verifying after a few minutes.
"""
async def signInboundV2(
    secret: str, raw: any, sender: str, to: str, headers: str, timestamp: str
) -> str {
    return await hmac_hex(secret, f"v2\n{timestamp}\n{sender}\n{to}\n{headers}\n", raw);
}

async def verifyInboundSignatureV2(
    secret: str,
    signature: str,
    raw: any,
    sender: str,
    to: str,
    headers: str,
    timestamp: str,
    nowSeconds: any = None,
) -> bool {
    moment = globalThis.Math.floor(globalThis.Date.now() / 1000)
        if nowSeconds is None
        else nowSeconds;
    sent_at = globalThis.Number(timestamp);
    if not globalThis.Number.isFinite(sent_at)
        or globalThis.Math.abs(moment - sent_at) > INBOUND_SIGNATURE_MAX_AGE_SECONDS
    {
        return False;
    }
    return same_text(await signInboundV2(secret, raw, sender, to, headers, timestamp), signature);
}
