# Compares two strings without stopping at the first difference.
def:priv same_text(a: any, b: any) -> bool {
    n = a.length;
    return n == b.length and sum(a.charCodeAt(i) ^ b.charCodeAt(i) for i in range(n)) == 0;
}

# Verifies a Svix-signed webhook (what Resend sends): HMAC-SHA256 over `${id}.${timestamp}.${body}`
# keyed by the base64 secret after `whsec_`, checked against every `v1,<base64>` signature entry.
async def verifySvixSignature(
    secret: str, headers: any, body: str, tolerance: any = None, now: any = None
) -> bool {
    (mid, stamp, signature) = [at(headers, k) for k in ["id", "timestamp", "signature"]];
    seconds = globalThis.Number(stamp);
    moment = globalThis.Date.now() if now is None else now;
    late = globalThis.Math.abs(moment / 1000 - seconds) > (300 if tolerance is None else tolerance);
    if not (mid and stamp and signature) or not globalThis.Number.isFinite(seconds) or late {
        return False;
    }
    encoded = secret.removeprefix("whsec_");
    try {
        raw = new(globalThis.Uint8Array, [ord(c) for c in globalThis.atob(encoded)]);
    } except Exception {
        return False;
    }
    hmac = record({"name": "HMAC", "hash": "SHA-256"});
    key = await globalThis.crypto.subtle.importKey("raw", raw, hmac, False, ["sign"]);
    data = new(globalThis.TextEncoder).encode(f"{mid}.{stamp}.{body}");
    signed = new(globalThis.Uint8Array, await globalThis.crypto.subtle.sign("HMAC", key, data));
    expected = globalThis.btoa(globalThis.String.fromCharCode.apply(NULL, signed));
    pairs = [item.split(",") + [""] for item in signature.split(" ")];
    return any(e[0] == "v1" and e[1] and same_text(e[1], expected) for e in pairs);
}
