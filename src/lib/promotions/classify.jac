import from "drizzle-orm" { and as all_of, eq }

"""Decides the category of one inbound message and the sender key to store with it. Runs in
every promotions mode, so the view is ready the moment a mailbox turns it on. Classification
must never block delivery: any failure, including a missing table before the migration, means
"no override" or "not promotions". `contactSource` is `contacts.source` of the sender, when known."""
async def classifyInboundCategory(db: any, given: any) -> dict[str, any] {
    sender = toSenderAddress(given["from"]);
    forced: any = NULL;
    if sender {
        preferences = mailboxSenderPreferences;
        try {
            rows = await db.select(record({"override": preferences.categoryOverride})).from(
                preferences
            ).where(
                all_of(
                    eq(preferences.mailboxId, given["mailboxId"]),
                    eq(preferences.senderAddress, sender),
                ),
            ).limit(1);
            forced = either(rows[0]["override"], NULL) if len(rows) else NULL;
        } except Exception as error {
            # What JavaScript threw, not the exception Jac caught it as.
            caught: any = error;
            if not isMissingTableError(getattr(caught, "js", caught)) {
                # Unknown failure: the override may say "always Inbox", so leave the mail in Inbox.
                globalThis.console.error(
                    f"Sender override lookup failed for mailbox {given['mailboxId']}",
                    getattr(caught, "js", caught),
                );
                return {"category": NULL, "senderAddress": sender};
            }
        }
    }
    category = decideCategory({
        "verdict": detectBulkMail(given["headers"]),
        "override": forced,
        "correspondent": at(given, "contactSource") in ["manual", "outbound"],
    });
    return {"category": category, "senderAddress": sender};
}
