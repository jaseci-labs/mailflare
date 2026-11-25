glob:priv SITEVERIFY = "https://challenges.cloudflare.com/turnstile/v0/siteverify";

"""Checks a Turnstile token with Cloudflare; an installation without a secret key accepts everything."""
async def verifyTurnstileToken(env: any, request: any, token: any = None) -> any {
    key: any = env["TURNSTILE_SECRET_KEY"];
    secret = key.trim() if key else None;
    if not secret {
        return True;
    }
    if not isinstance(token, str) or not token.trim() or token.length > 2048 {
        return False;
    }
    try {
        (ip, once) = (either(getClientIp(request), None), newId("ts"));
        body = {"secret": secret, "response": token, "remoteip": ip, "idempotency_key": once};
        json = globalThis.JSON.stringify(record(body));
        sig = globalThis.AbortSignal.timeout(10000);
        headers = record({"Content-Type": "application/json"});
        init = record({"method": "POST", "headers": headers, "signal": sig, "body": json});
        response: any = await globalThis.fetch(SITEVERIFY, init);
    } except Exception {
        return False;
    }
    return (await response.json())["success"] if response.ok else False;
}
