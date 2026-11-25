"""A JMAP Id[Boolean] set, as `mailboxIds` and `keywords` are defined.

Clients built on libraries that model these as lists send a plain array instead,
so both shapes are read; only entries set to true count.
"""
def idSetToList(value: any) -> list[str] {
    if globalThis.Array.isArray(value) {
        return [item for item in value if isinstance(item, str)];
    }
    if not value or globalThis.Object(value) is not value {
        return [];
    }
    return [id for (id, on) in entries(value) if on];
}

"""The keywords Mailflare stores as columns. `$draft` is implied by the Drafts-only rule, and unknown keywords are ignored."""
def importFlags(keywords: any) -> dict[str, bool] {
    ids = idSetToList(keywords);
    return {"read": KEYWORD_SEEN in ids, "starred": KEYWORD_FLAGGED in ids};
}

"""`receivedAt` is a UTCDate in RFC 8621, but client libraries also send epoch seconds or milliseconds.

Anything unusable falls back to the caller's default.
"""
def parseReceivedAt(value: any) -> any {
    stamp: any = None;
    if isinstance(value, (int, float)) and globalThis.Number.isFinite(value) {
        # Seconds until the value is too large to be one: 1e12 is the year 33658 in seconds.
        stamp = value * 1000 if value < 1e12 else value;
    } elif isinstance(value, str) and value.strip() {
        stamp = value.strip();
    } else {
        return NULL;
    }
    date = new(globalThis.Date, stamp);
    return NULL if globalThis.Number.isNaN(date.getTime()) else date;
}

"""Where a new message may be created: exactly one JMAP Mailbox, a Drafts role mailbox the key can write to.

Importing into arbitrary mailboxes would have to answer for threading, spam
scoring and inbound state, so v1 takes the same target `Email/set` create does.
"""
def resolveDraftsMailbox(mailboxIds: any, writable: any) -> dict[str, any] {
    def invalid(description: str) -> dict[str, any] {
        return {
            "error": {
                "type": "invalidProperties",
                "properties": ["mailboxIds"],
                "description": description,
            },
        };
    }
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
