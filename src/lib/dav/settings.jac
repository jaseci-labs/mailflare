import from "drizzle-orm" { eq }

glob:priv CACHE_MS: int = 30000,
          cached: any = None;

"""Forget the cached switch, so an administrator's change shows at once in this isolate (others catch up within 30 s)."""
def clearDavEnabledCache {
    cached = None;
}

"""
Whether the administrator turned CalDAV/CardDAV on. Off when the row or the column is missing (migration 0097
not applied yet) and on any read error, because the safe answer for a protocol that accepts credentials is "off".
Cached for 30 s per isolate: this runs before authentication on every request.
"""
async def isDavEnabled(env: any) -> bool {
    now = globalThis.Date.now();
    if cached is not None and now - cached["at"] < CACHE_MS {
        return cached["value"];
    }
    value = False;
    try {
        rows = await getDb(env).select(record({"enabled": appSettings.davEnabled})).from(
            appSettings
        ).where(eq(appSettings.id, "default")).limit(1);
        value = bool(rows.length and rows[0].enabled);
    } except Exception as error {
        if not isMissingColumnError(error) {
            globalThis.console.warn(
                "Could not read the CalDAV/CardDAV switch; treating it as off", error
            );
        }
    }
    cached = {"value": value, "at": now};
    return value;
}
