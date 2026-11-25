import from "drizzle-orm" { and as all_of, count, desc, eq }

glob MAX_SUPPRESSION_PAGE: int = 100;

glob:priv REASONS: list[str] = ["hard_bounce", "complaint", "manual"],
          table: any = emailSuppressions;

type SuppressionItem = dict[str, any];

"""A whole number from `value`, `fallback` where it is missing, zero or not a number."""
def:priv whole(value: any, fallback: int) -> any {
    number = globalThis.Math.trunc(either(value, fallback));
    return fallback if globalThis.Number.isNaN(number) or number == 0 else number;
}

async def listSuppressions(env: any, domainId: str, query: any) -> dict[str, any] {
    (reason, term) = (at(query, "reason"), at(query, "q"));
    term = term.trim() if term else None;
    where = all_of(
        eq(table.domainId, domainId),
        eq(table.reason, reason) if isinstance(reason, str) and reason in REASONS else None,
        containsLike(table.email, term) if term else None,
    );
    limit = min(max(whole(at(query, "limit"), 50), 1), MAX_SUPPRESSION_PAGE);
    offset = max(whole(at(query, "offset"), 0), 0);
    db = getDb(env);
    found = await globalThis.Promise.all([
        db.select({
            "id": table.id,
            "email": table.email,
            "reason": table.reason,
            "source": table.source,
            "detail": table.detail,
            "confirmed": table.confirmed,
            "eventCount": table.eventCount,
            "firstEventAt": table.firstEventAt,
            "lastEventAt": table.lastEventAt,
        }).from(table).where(where).orderBy(desc(table.lastEventAt), table.email).limit(
            limit
        ).offset(offset),
        db.select({"total": count()}).from(table).where(where),
    ]);
    (items, totals) = found;
    return {"items": items, "total": at(totals[0], "total", 0) if totals.length else 0};
}

def:priv mine(domainId: str, id: str) -> any {
    return all_of(eq(table.id, id), eq(table.domainId, domainId));
}

"""The removed address, or null when the id is not an entry of this domain."""
async def removeSuppression(env: any, domainId: str, id: str) -> any {
    removed = await getDb(env).delete(table).where(mine(domainId, id)).returning({
        "email": table.email,
    });
    return removed[0] if removed.length else NULL;
}

"""Makes an entry of this domain enforceable; the address, or null when the id is not an entry of this domain."""
async def confirmSuppression(env: any, domainId: str, id: str) -> any {
    confirmed = await getDb(env).update(table).set({"confirmed": True}).where(
        mine(domainId, id)
    ).returning({"email": table.email});
    return confirmed[0] if confirmed.length else NULL;
}
