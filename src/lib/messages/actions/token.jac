# MAX_UNDO_AGE_MS bounds how long an undo stays valid; tokens may be issued up to a minute ahead.
glob MAX_UNDO_AGE_MS: int = 10 * 60_000;

def:priv to_base64url(data: any) -> str {
    binary = "";
    for i in range(0, data.length, 0x8000) {
        binary += globalThis.String.fromCharCode.apply(NULL, data.subarray(i, i + 0x8000));
    }
    return globalThis.btoa(binary).replace("+", "-").replace("/", "_").rstrip("=");
}

def:priv from_base64url(value: any) -> any {
    padded = value.replace("-", "+").replace("_", "/") + "=" * ((4 - value.length % 4) % 4);
    try {
        return new(globalThis.Uint8Array, [ord(c) for c in globalThis.atob(padded)]);
    } except Exception {
        return NULL;
    }
}

async def:priv token_key(secret: str) -> any {
    raw = new(globalThis.TextEncoder).encode(f"message-action-undo\n{secret}");
    hmac = record({"name": "HMAC", "hash": "SHA-256"});
    return await globalThis.crypto.subtle.importKey("raw", raw, hmac, False, ["sign", "verify"]);
}

# Signs the exact server-confirmed before/after states, so a client cannot invent an undo.
async def signUndoToken(secret: str, payload: any) -> str {
    enc = new(globalThis.TextEncoder);
    body = to_base64url(enc.encode(globalThis.JSON.stringify(payload)));
    signed = await globalThis.crypto.subtle.sign("HMAC", await token_key(secret), enc.encode(body));
    return f"{body}.{to_base64url(new(globalThis.Uint8Array, signed))}";
}

# Null for tampered, malformed or expired tokens. Version 2 binds the token to the session user
# and a single-use claim nonce.
async def verifyUndoToken(secret: str, token: any, now: any = None) -> any {
    moment = globalThis.Date.now() if now is None else now;
    (body, signature) = (token.split(".") + [""])[:2];
    sig = from_base64url(signature) if body and signature else NULL;
    if nil(sig) {
        return NULL;
    }
    key = await token_key(secret);
    if not await globalThis.crypto.subtle.verify(
        "HMAC", key, sig, new(globalThis.TextEncoder).encode(body)
    ) {
        return NULL;
    }
    data = from_base64url(body);
    try {
        payload = NULL
            if nil(data)
            else globalThis.JSON.parse(new(globalThis.TextDecoder).decode(data));
    } except Exception {
        return NULL;
    }
    if not is_object(payload) {
        return NULL;
    }
    (issued, user, nonce) = [at(payload, k) for k in ["issuedAt", "userId", "nonce"]];
    shaped = at(payload, "v") == 2 and globalThis.Array.isArray(at(payload, "records"));
    named = isinstance(user, str) and user and isinstance(nonce, str) and nonce;
    fresh = globalThis.Number.isFinite(issued)
        and moment - MAX_UNDO_AGE_MS <= issued <= moment + 60_000;
    return payload if shaped and named and fresh else NULL;
}

async def signUndoTokenForEnv(env: any, payload: any) -> str {
    return await signUndoToken(await getServerSecret(env), payload);
}

async def verifyUndoTokenForEnv(env: any, token: any, now: any = None) -> any {
    return await verifyUndoToken(await getServerSecret(env), token, now);
}
