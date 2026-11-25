# `mailboxes`-scoped sender key. MySQL indexes the column as varchar(191), so a longer address is null, never truncated.
glob:priv MAX_SENDER_ADDRESS = 191;

"""Lower-cased bare address of a From header value, or null when empty or too long to index."""
def toSenderAddress(sender: str) -> any {
    address: any = normalizeEmailAddress(sender);
    return address if address and address.length <= MAX_SENDER_ADDRESS else NULL;
}

"""The user's per-sender override beats headers; discussion lists and plain mail are never
promotions; people the user wrote to (manual or outbound contacts) belong in Inbox."""
def decideCategory(given: any) -> any {
    forced = at(given, "override");
    if forced {
        return "promotions" if forced == "promotions" else NULL;
    }
    marketing = given["verdict"]["kind"] == "marketing" and not at(given, "correspondent");
    return "promotions" if marketing else NULL;
}
