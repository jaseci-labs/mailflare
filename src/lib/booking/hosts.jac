import from "drizzle-orm" { and as both, eq, inArray }

"""The hosts of a booking event, owner first. Older booking events have only the owner."""
def parseBookingHostIds(value: any, ownerId: str) -> list[str] {
    try {
        parsed = globalThis.JSON.parse(value);
        if globalThis.Array.isArray(parsed)
            and parsed.length
            and all([isinstance(id, str) and id.length > 0 for id in parsed])
            and new(globalThis.Set, parsed).size == parsed.length
        {
            return [ownerId] + [id for id in parsed if id != ownerId];
        }
    } except Exception {
        return [ownerId];
    }
    return [ownerId];
}

"""The owner and the requested co-hosts when all are active calendar users (at most 20), else null."""
async def validBookingHostIds(db: any, ownerId: str, requested: any, canManageHosts: bool) -> any {
    hostIds = [ownerId] + [id for id in requested if id != ownerId];
    if len(hostIds) > 20 or (not canManageHosts and len(hostIds) > 1) {
        return NULL;
    }
    active = await db.select(record({"id": users.id})).from(users).where(
        both(inArray(users.id, hostIds), eq(users.disabled, False), eq(users.calendarEnabled, True))
    );
    return hostIds if active.length == len(hostIds) else NULL;
}
