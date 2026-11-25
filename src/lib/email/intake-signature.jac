glob INBOUND_SIGNATURE_MAX_AGE_SECONDS: int = 300;

# Hex HMAC-SHA256 of `prefix` followed by the raw body.
async def:priv hmac_hex(secret: str, prefix: str, raw: any) -> str {
    (enc, subtle) = (new(globalThis.TextEncoder), globalThis.crypto.subtle);
    hmac = record({"name": "HMAC", "hash": "SHA-256"});
    key = await subtle.importKey("raw", enc.encode(secret), hmac, False, ["sign"]);
    data = await new(globalThis.Blob, [enc.encode(prefix), raw]).arrayBuffer();
    signed = new(globalThis.Uint8Array, await subtle.sign("HMAC", key, data));
    return "".join([globalThis.String(b.toString(16)).padStart(2, "0") for b in signed]);
}

# Compares two strings without stopping at the first difference.
def:priv same_text(a: any, b: any) -> bool {
    n = a.length;
    return n == b.length and sum(a.charCodeAt(i) ^ b.charCodeAt(i) for i in range(n)) == 0;
}

# HMAC-SHA256 over `from\nto\n` + raw body, hex encoded. Shared with the relay Worker.
async def signInbound(secret: str, raw: any, sender: str, to: str) -> str {
    return await hmac_hex(secret, f"{sender}\n{to}\n", raw);
}

async def verifyInboundSignature(secret: str, sig: str, raw: any, sender: str, to: str) -> bool {
    return same_text(await signInbound(secret, raw, sender, to), sig);
}

# Version 2 also covers the header map and a Unix timestamp (seconds), so neither can be altered in
# transit and a captured request stops verifying after a few minutes.
async def signInboundV2(
    secret: str, raw: any, sender: str, to: str, headers: str, timestamp: str
) -> str {
    return await hmac_hex(secret, f"v2\n{timestamp}\n{sender}\n{to}\n{headers}\n", raw);
}

async def verifyInboundSignatureV2(
    secret: str, sig: str, raw: any, sender: str, to: str, headers: str, stamp: str, now: any = None
) -> bool {
    moment = globalThis.Math.floor(globalThis.Date.now() / 1000) if now is None else now;
    sent_at = globalThis.Number(stamp);
    late = globalThis.Math.abs(moment - sent_at) > INBOUND_SIGNATURE_MAX_AGE_SECONDS;
    if not globalThis.Number.isFinite(sent_at) or late {
        return False;
    }
    return same_text(await signInboundV2(secret, raw, sender, to, headers, stamp), sig);
}
