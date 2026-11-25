import from "drizzle-orm" { sql }

"""Counts one more message seen for each reputation key of a mailbox."""
async def recordReputationObservation(env: any, mailboxId: str, keys: any) {
    if len(keys) == 0 {
        return;
    }
    db = getDb(env);
    now = new(globalThis.Date);
    await db.batch([
        db.insert(spamReputation).values({
            "mailboxId": mailboxId,
            "type": item["type"],
            "key": item["key"],
            "messagesSeen": 1,
            "spamCount": 0,
            "hamCount": 0,
            "firstSeenAt": now,
            "lastSeenAt": now,
        }).onConflictDoUpdate({
            "target": [spamReputation.mailboxId, spamReputation.type, spamReputation.key],
            "set": {
                "messagesSeen": sql(["", " + 1"], spamReputation.messagesSeen),
                "lastSeenAt": now,
            },
        })
        for item in keys
    ]);
}
