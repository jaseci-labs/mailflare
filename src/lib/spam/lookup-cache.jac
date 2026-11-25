"""
Caches results of external spam lookups (blocklists, RDAP) per isolate and in object storage. The Cache API
is not an option: it does nothing on workers.dev hostnames and does not exist in the self-hosted runtime.
"""

glob:priv memory: dict[str, tuple[any, any]] = {},
          MAX_MEMORY_ENTRIES: int = 2000,
          STORAGE_PREFIX: str = "spam-cache/";

"""Keeps a value in memory, dropping the oldest entry when full."""
def:priv remember(key: str, expires: any, value: any) {
    if len(memory) >= MAX_MEMORY_ENTRIES {
        del memory[next(iter(memory))];
    }
    memory[key] = (expires, value);
}

async def cachedLookup(bucket: any, key: str, ttlSeconds: any, load: any) -> any {
    now = globalThis.Date.now();
    if key in memory and memory[key][0] > now {
        return memory[key][1];
    }
    storage_key = f"{STORAGE_PREFIX}{key}.json";
    if bucket {
        try {
            found = await bucket.get(storage_key);
            stored = await found.json() if found else None;
            if stored and stored.expires > now {
                remember(key, stored.expires, stored.value);
                return stored.value;
            }
        } except Exception {}
    }
    value = await load();
    expires = now + ttlSeconds(value) * 1000;
    remember(key, expires, value);
    if bucket {
        await bucket.put(
            storage_key,
            globalThis.JSON.stringify(record({"expires": expires, "value": value})),
            record({"httpMetadata": record({"contentType": "application/json"})}),
        ).catch(lambda (e: any) -> any { None });
    }
    return value;
}
