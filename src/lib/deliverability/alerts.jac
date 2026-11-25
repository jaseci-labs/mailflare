import from "drizzle-orm" { and as all_of, desc, eq, isNull }

glob:priv OPEN_LIMIT: int = 50;

def:priv parse_detail(value: str) -> any {
    try {
        return globalThis.JSON.parse(value);
    } except Exception {
        return {};
    }
}

async def listOpenAlerts(env: any, domainId: str) -> list[any] {
    rows = await getDb(env).select().from(deliverabilityAlerts).where(
        all_of(
            eq(deliverabilityAlerts.domainId, domainId), isNull(deliverabilityAlerts.acknowledgedAt)
        ),
    ).orderBy(desc(deliverabilityAlerts.createdAt), desc(deliverabilityAlerts.id)).limit(
        OPEN_LIMIT
    );
    return [
        {
            "id": row.id,
            "kind": row.kind,
            "day": row.day,
            "detail": parse_detail(row.detail),
            "createdAt": row.createdAt.toISOString(),
        }
        for row in rows
    ];
}

"""Marks one alert of this domain as seen. False when it does not exist, belongs to another domain or was already acknowledged."""
async def acknowledgeAlert(env: any, domainId: str, alertId: str, userId: str) -> bool {
    updated = await getDb(env).update(deliverabilityAlerts).set({
        "acknowledgedAt": new(globalThis.Date),
        "acknowledgedByUserId": userId,
    }).where(
        all_of(
            eq(deliverabilityAlerts.id, alertId),
            eq(deliverabilityAlerts.domainId, domainId),
            isNull(deliverabilityAlerts.acknowledgedAt),
        ),
    ).returning({"id": deliverabilityAlerts.id});
    return updated.length > 0;
}
