# A JMAP Id[Boolean] set (`mailboxIds`, `keywords`); clients whose libraries model these as lists
# send a plain array, so both shapes are read; only entries set to true count.
def idSetToList(value: any) -> list[str] {
    if globalThis.Array.isArray(value) {
        return [item for item in value if isinstance(item, str)];
    }
    return [id for (id, on) in entries(value) if on] if is_object(value) else [];
}

# `$draft` is implied by the Drafts-only rule, and unknown keywords are ignored.
def importFlags(keywords: any) -> dict[str, bool] {
    ids = idSetToList(keywords);
    return {"read": KEYWORD_SEEN in ids, "starred": KEYWORD_FLAGGED in ids};
}

# A UTCDate in RFC 8621, but client libraries also send epoch seconds or milliseconds.
def parseReceivedAt(value: any) -> any {
    num = isinstance(value, (int, float)) and globalThis.Number.isFinite(value);
    text = isinstance(value, str) and value.strip();
    if not num and not text {
        return NULL;
    }
    # Seconds until the value is too large to be one: 1e12 is the year 33658 in seconds.
    date = new(globalThis.Date, (value * 1000 if value < 1e12 else value) if num else text);
    return NULL if globalThis.Number.isNaN(date.getTime()) else date;
}

def:priv invalid(why: str) -> dict[str, any] {
    return {
        "error": {"type": "invalidProperties", "properties": ["mailboxIds"], "description": why},
    };
}

# Exactly one writable Drafts mailbox: importing elsewhere would have to answer for threading,
# spam scoring and inbound state, so v1 takes the same target `Email/set` create does.
def resolveDraftsMailbox(mailboxIds: any, writable: any) -> dict[str, any] {
    ids = idSetToList(mailboxIds);
    if len(ids) != 1 {
        return invalid("A message belongs to exactly one mailbox");
    }
    ref = decodeMailboxRef(ids[0]);
    if not ref or not writable.has(ref["mailboxId"]) {
        return invalid("Unknown mailbox");
    }
    if ref["kind"] != "role" or ref["role"] != "drafts" {
        return invalid("New messages can only be created in a Drafts mailbox");
    }
    return {"mailboxId": ref["mailboxId"]};
}
