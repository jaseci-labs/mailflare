# Calendar tools that change or remove existing events; an assistant may only propose these.
glob CONFIRMED_CALENDAR_TOOLS: any = new(globalThis.Set, ["update_events", "delete_events"]);
glob:priv ENC: any = new(globalThis.TextEncoder);

# Base64url of the UTF-8 of `text` (also of the signature, whose bytes become characters first).
def:priv encode(text: any) -> any {
    b64: any = globalThis.btoa("".join([chr(b) for b in ENC.encode(text)]));
    return sub(b64.replaceAll("+", "-").replaceAll("/", "_"), rx("=+$"), "");
}

async def:priv mac(env: any, payload: str) -> any {
    (subtle, hmac) = (globalThis.crypto.subtle, record({"name": "HMAC", "hash": "SHA-256"}));
    secret = ENC.encode(f"calendar-confirmation\n{await getServerSecret(env)}");
    key = await subtle.importKey("raw", secret, hmac, False, ["sign"]);
    signed = await subtle.sign("HMAC", key, ENC.encode(payload));
    return encode("".join([chr(b) for b in new(globalThis.Uint8Array, signed)]));
}

# A token the user opens in the app to approve exactly this change; the model cannot redeem it.
async def createCalendarConfirmation(env: any, uid: any, tool: any, x: any, t: any = None) -> any {
    expiresAt = (globalThis.Date.now() if t is None else t) + 15 * 60000;
    claim = record({"userId": uid, "name": tool, "input": x, "expiresAt": expiresAt});
    payload = encode(globalThis.JSON.stringify(claim));
    return f"{payload}.{await mac(env, payload)}";
}

async def readCalendarConfirmation(env: any, token: any, userId: str, now: any = None) -> any {
    (payload, sig) = (token.split(".") + [""])[:2];
    x: any = await mac(env, payload) if payload and sig else "";
    bad = not x or x.length != sig.length;
    # Constant time: every character is compared whether or not an earlier one differed.
    if bad or sum([x.charCodeAt(i) ^ sig.charCodeAt(i) for i in range(x.length)]) != 0 {
        return NULL;
    }
    try {
        b = globalThis.atob(payload.replaceAll("-", "+").replaceAll("_", "/"));
        raw = new(globalThis.Uint8Array, [ord(c) for c in b]);
        p = globalThis.JSON.parse(new(globalThis.TextDecoder).decode(raw));
        late = globalThis.Number(p["expiresAt"]) < (globalThis.Date.now() if now is None else now);
        ok = p["userId"] == userId and not late and CONFIRMED_CALENDAR_TOOLS.has(p["name"]);
        return p if ok else NULL;
    } except Exception {
        return NULL;
    }
}
