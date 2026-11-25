# Subscriptions only looks at the last 90 days, one page of senders at a time.
glob SUBSCRIPTION_WINDOW_DAYS = 90,
     SUBSCRIPTIONS_PAGE_SIZE = 50,
     # "Trash all" reaches at most this many rows of the last SWEEP_WINDOW_DAYS days per request:
     # every row written fires the change-log and trashed_at triggers, and D1 meters row writes.
     SWEEP_WINDOW_DAYS = 90,
     MAX_SWEEP_ROWS = 500,
     # An UPDATE binds the new status, the mailbox, the sender guard (up to 5) and one id per row; D1 allows 100.
     SWEEP_CHUNK_SIZE = 80,
     # A sender that mails again later than this after an unsubscribe is "still sending".
     STILL_SENDING_GRACE_MS = 2 * 86400000;

def windowStart(now: any, days: any) -> any {
    return new(globalThis.Date, now.getTime() - days * 86400000);
}

"""`body.k` of a request body that is an object, else undefined."""
def:priv field(body: any, k: str) -> any {
    return body[k] if globalThis.Object(body) is body else None;
}

def:priv is_text(v: any) -> bool {
    return globalThis.String(v) is v;
}

def parseTrashBody(body: any) -> dict[str, any] {
    (mailbox, sender, preview) = (
        field(body, "mailboxId"),
        field(body, "senderAddress"),
        field(body, "previewOnly"),
    );
    if not is_text(mailbox) or not mailbox {
        return {"error": "mailboxId is required"};
    }
    address = toSenderAddress(sender) if is_text(sender) else NULL;
    if not address {
        return {"error": "senderAddress must be a valid address of at most 191 characters"};
    }
    if preview is not None and preview is not True and preview is not False {
        return {"error": "previewOnly must be a boolean"};
    }
    return {"mailboxId": mailbox, "senderAddress": address, "previewOnly": preview is True};
}

# Subscriptions "Block" uses the existing POST /api/contacts/block. blockContact files a routing rule
# with action "trash": blocked mail goes to Trash, it is never rejected at SMTP time. Wording says Trash.
def isStillSending(lastReceived: any, unsubscribedAt: any) -> bool {
    return unsubscribedAt is not NULL
        and lastReceived.getTime() > unsubscribedAt.getTime() + STILL_SENDING_GRACE_MS;
}
