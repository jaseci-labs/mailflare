import from "drizzle-orm" { and as all_of, count, desc, eq, gte, inArray, isNull, ne, or as any_of }

"""Rows of one sender that a move to `target` would still change. Only unfiled received mail: Trash, Spam, Sent and filed mail keep their category."""
def:priv still_to_move(mailboxId: str, senderAddress: str, target: str) -> any {
    return all_of(
        eq(messages.mailboxId, mailboxId),
        eq(messages.senderAddress, senderAddress),
        eq(messages.direction, "inbound"),
        eq(messages.status, "received"),
        isNull(messages.folderId),
        # `primary` counts as Inbox, so moving to Promotions changes null and primary rows, and moving to Inbox changes only promotions.
        any_of(isNull(messages.category), ne(messages.category, "promotions"))
            if target == "promotions"
            else eq(messages.category, "promotions"),
    );
}

"""Re-files one sender's mail, bounded: the newest MAX_REFILE_ROWS rows of the last REFILE_WINDOW_DAYS days,
selected by id and written in chunks under D1's parameter limit. Never an unbounded UPDATE.
`remainingOlder` counts that sender's rows still outside the target (older than the window or beyond the cap).
Rows with a null sender_address are not matched: legacy rows are only reachable through the single-message move."""
async def refileSenderMessages(db: any, given: any) -> dict[str, any] {
    (mailbox, sender, target) = (given["mailboxId"], given["senderAddress"], given["target"]);
    since = refileCutoff(either(at(given, "now"), new(globalThis.Date)));
    candidates = await db.select(record({"id": messages.id})).from(messages).where(
        all_of(still_to_move(mailbox, sender, target), gte(messages.createdAt, since))
    ).orderBy(desc(messages.createdAt), desc(messages.id)).limit(MAX_REFILE_ROWS);
    changed = 0;
    for ids in chunk([row["id"] for row in candidates], REFILE_CHUNK_SIZE) {
        # The guard repeats the category test so a row moved meanwhile is neither rewritten nor counted.
        updated = await db.update(messages).set(record({"category": target})).where(
            all_of(
                inArray(messages.id, ids),
                eq(messages.mailboxId, mailbox),
                still_to_move(mailbox, sender, target),
            ),
        ).returning(record({"id": messages.id}));
        changed += len(updated);
    }
    rows = await db.select(record({"remaining": count()})).from(messages).where(
        still_to_move(mailbox, sender, target)
    );
    return {"changed": changed, "remainingOlder": globalThis.Number(rows[0]["remaining"])};
}

"""Stores (or with null clears) the sender's override. Clearing never moves mail."""
async def setSenderOverride(db: any, given: any) {
    preferences = mailboxSenderPreferences;
    values = {
        "categoryOverride": given["override"],
        "updatedByUserId": given["userId"],
        "updatedAt": new(globalThis.Date),
    };
    if given["override"] is NULL {
        await db.update(preferences).set(record(values)).where(
            all_of(
                eq(preferences.mailboxId, given["mailboxId"]),
                eq(preferences.senderAddress, given["senderAddress"]),
            ),
        );
        return;
    }
    await db.insert(preferences).values(
        record({
            "id": newId("msp"),
            "mailboxId": given["mailboxId"],
            "senderAddress": given["senderAddress"],
            **values,
        }),
    ).onConflictDoUpdate(
        record({
            "target": [preferences.mailboxId, preferences.senderAddress],
            "set": record(values),
        }),
    );
}
