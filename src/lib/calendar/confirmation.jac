# Calendar tools that change or remove existing events; an assistant may only propose these.
glob CONFIRMED_CALENDAR_TOOLS: any = new(globalThis.Set, ["update_events", "delete_events"]);
glob:priv ENC: any = new(globalThis.TextEncoder),
          CHARS: any = globalThis.String.fromCharCode,
          HMAC: any = record({"name": "HMAC", "hash": "SHA-256"});

# Base64url of the text's UTF-8, built in slices: spreading a large array into one call overflows the stack.
def:priv encode(text: any) -> any {
    d = ENC.encode(text);
    bin = "".join([CHARS.apply(NULL, d.subarray(i, i + 8192)) for i in range(0, d.length, 8192)]);
    b64 = sub(globalThis.btoa(bin), rx(r"\+", "g"), "-");
    return sub(sub(b64, rx("/", "g"), "_"), rx("=+$"), "");
}

# The signature's bytes as characters, then encoded like the payload.
async def:priv mac(env: any, payload: str) -> any {
    secret = ENC.encode(f"calendar-confirmation\n{await getServerSecret(env)}");
    key = await globalThis.crypto.subtle.importKey("raw", secret, HMAC, False, ["sign"]);
    signed = await globalThis.crypto.subtle.sign("HMAC", key, ENC.encode(payload));
    return encode(CHARS.apply(NULL, new(globalThis.Uint8Array, signed)));
}

# A token the signed-in user opens in the app to approve exactly this change; the model cannot redeem it.
async def createCalendarConfirmation(env: any, uid: any, tool: any, x: any, t: any = None) -> any {
    expiresAt = (globalThis.Date.now() if t is None else t) + 15 * 60000;
    claim = record({"userId": uid, "name": tool, "input": x, "expiresAt": expiresAt});
    payload = encode(globalThis.JSON.stringify(claim));
    return f"{payload}.{await mac(env, payload)}";
}

async def readCalendarConfirmation(env: any, token: str, userId: str, now: any = None) -> any {
    cur = globalThis.Date.now() if now is None else now;
    (payload, signature) = (token.split(".") + [""])[:2];
    sig = globalThis.String(signature);
    expected: any = await mac(env, payload) if payload and signature else "";
    # Constant time: every character is compared whether or not an earlier one differed.
    codes = [expected.charCodeAt(i) ^ sig.charCodeAt(i) for i in range(expected.length)];
    same = expected and expected.length == sig.length and sum(codes) == 0;
    try {
        bin = globalThis.atob(sub(sub(payload, rx("-", "g"), "+"), rx("_", "g"), "/"));
        raw = globalThis.Uint8Array.from(bin, lambda (c: any) -> int { c.charCodeAt(0) });
        p = globalThis.JSON.parse(new(globalThis.TextDecoder).decode(raw)) if same else NULL;
        ok = p["userId"] == userId and not p["expiresAt"] < cur;
        return p if ok and CONFIRMED_CALENDAR_TOOLS.has(p["name"]) else NULL;
    } except Exception {
        return NULL;
    }
}
