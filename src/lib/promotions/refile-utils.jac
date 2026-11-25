# Bounded re-files only reach this far back and this many rows per request: every row written
# fires the change-log and trashed_at triggers, and D1 meters row writes.
glob REFILE_WINDOW_DAYS = 90,
     MAX_REFILE_ROWS = 500,
     # D1 allows 100 bound parameters per statement. An update binds the new value, the mailbox,
     # the category guard and one id per row.
     REFILE_CHUNK_SIZE = 90;

glob:priv CATEGORIES: list[str] = ["promotions", "inbox"];

def refileCutoff(now: any) -> any {
    return new(globalThis.Date, now.getTime() - REFILE_WINDOW_DAYS * 86400000);
}

def chunk(items: any, size: int) -> list[any] {
    return [items[i:i + size] for i in range(0, len(items), size)];
}

"""The stored marker for a destination: Inbox is the explicit `primary`, never a null the backfill could reclassify."""
def targetOf(category: str) -> str {
    return "primary" if category == "inbox" else "promotions";
}

"""`body.k` of a request body that is an object, else undefined."""
def:priv field(body: any, k: str) -> any {
    return body[k] if globalThis.Object(body) is body else None;
}

def:priv is_text(v: any) -> bool {
    return globalThis.String(v) is v;
}

def parseCategoryMoveBody(body: any) -> dict[str, any] {
    (category, apply) = (field(body, "category"), field(body, "applyToSender"));
    if not is_text(category) or category not in CATEGORIES {
        return {"error": "category must be promotions or inbox"};
    }
    if apply is not None and apply is not True and apply is not False {
        return {"error": "applyToSender must be a boolean"};
    }
    return {"category": category, "applyToSender": apply is True};
}

def parsePreferenceBody(body: any) -> dict[str, any] {
    (mailbox, sender, category) = (
        field(body, "mailboxId"),
        field(body, "senderAddress"),
        field(body, "category"),
    );
    if not is_text(mailbox) or not mailbox {
        return {"error": "mailboxId is required"};
    }
    address = toSenderAddress(sender) if is_text(sender) else NULL;
    if not address {
        return {"error": "senderAddress must be a valid address of at most 191 characters"};
    }
    if category is not NULL and (not is_text(category) or category not in CATEGORIES) {
        return {"error": "category must be inbox, promotions or null"};
    }
    return {"mailboxId": mailbox, "senderAddress": address, "category": category};
}

type RefileTarget = any;
