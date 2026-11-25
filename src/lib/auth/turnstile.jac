"""Checks a Turnstile token with Cloudflare; an installation without a secret key accepts everything."""
async def verifyTurnstileToken(env: any, request: any, token: any = None) -> any {
    key: any = at(env, "TURNSTILE_SECRET_KEY");
    secret = key.trim() if key else None;
    if not secret {
        return True;
    }
    if not isinstance(token, str) or not token.trim() or token.length > 2048 {
        return False;
    }
    try {
        response = await globalThis.fetch(
            "https://challenges.cloudflare.com/turnstile/v0/siteverify",
            record({
                "method": "POST",
                "headers": record({"Content-Type": "application/json"}),
                "signal": globalThis.AbortSignal.timeout(10000),
                "body": globalThis.JSON.stringify(
                    record({
                        "secret": secret,
                        "response": token,
                        "remoteip": either(getClientIp(request), None),
                        "idempotency_key": newId("ts"),
                    }),
                ),
            }),
        );
    } except Exception {
        return False;
    }
    if not response.ok {
        return False;
    }
    return (await response.json())["success"];
}
