glob:priv OBJECT_KEY: str = "config/signing-secret";

def:priv hex(data: any) -> str {
    return "".join([byte.toString(16).padStart(2, "0") for byte in list(data)]);
}

"""A secret only this installation knows, for signing short-lived tokens. Deployment secrets are
preferred; otherwise one is generated once and kept in the bucket, so no setup is required."""
async def getServerSecret(env: any) -> str {
    configured = at(env, "CF_TOKEN") or at(env, "CF_API_KEY") or at(env, "INBOUND_WEBHOOK_SECRET");
    if configured {
        return configured;
    }
    existing = await env.BUCKET.get(OBJECT_KEY);
    if existing {
        return (await existing.text()).trim();
    }
    generated = hex(globalThis.crypto.getRandomValues(new(globalThis.Uint8Array, 32)));
    await env.BUCKET.put(OBJECT_KEY, generated);
    # Two first requests can race; whichever object won is the secret both must use.
    stored = await env.BUCKET.get(OBJECT_KEY);
    return (await stored.text()).trim() if stored else generated;
}
