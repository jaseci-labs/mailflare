glob:priv KEY: str = "config/signing-secret";

"""A secret only this installation knows, for signing short-lived tokens. Deployment secrets are
preferred; otherwise one is generated once and kept in the bucket, so no setup is required."""
async def getServerSecret(env: any) -> str {
    configured = at(env, "CF_TOKEN") or at(env, "CF_API_KEY") or at(env, "INBOUND_WEBHOOK_SECRET");
    existing = None if configured else await env.BUCKET.get(KEY);
    if configured or existing {
        return configured or (await existing.text()).trim();
    }
    octets = globalThis.crypto.getRandomValues(new(globalThis.Uint8Array, 32));
    generated = "".join([b.toString(16).padStart(2, "0") for b in list(octets)]);
    await env.BUCKET.put(KEY, generated);
    # Two first requests can race; whichever object won is the secret both must use.
    stored = await env.BUCKET.get(KEY);
    return (await stored.text()).trim() if stored else generated;
}
