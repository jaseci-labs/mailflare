"""Writes, reads back and deletes a small object: a wrong key, bucket or endpoint shows before mail does."""
async def testStorage(env: any) -> any {
    (started, key, ok, error) = (globalThis.Date.now(), f"healthcheck/{newId('chk')}", True, None);
    payload = f"mailflare {new(globalThis.Date).toISOString()}";
    try {
        await env.BUCKET.put(key, payload, record({"httpMetadata": {"contentType": "text/plain"}}));
        found: any = await env.BUCKET.get(key);
        text: any = (await found.text()) if found else NULL;
        await env.BUCKET.delete(key);
        (ok, error) = (text == payload, "Object read back did not match what was written");
    } except Exception as caught {
        c: any = caught;
        (e, ok) = (getattr(c, "js", c), False);
        await env.BUCKET.delete(key).catch(lambda -> any { None });
        error = e.message if isinstance(e, globalThis.Error) else "Storage test failed";
    }
    t = globalThis.Date.now() - started;
    return {"ok": True, "latencyMs": t} if ok else {"ok": False, "error": error, "latencyMs": t};
}
