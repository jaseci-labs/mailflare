glob:priv BRACKETS: any = rx(r"^<|>$", "g");

# One mailbox parameter plus two variants per ID: at most 81 of D1's 100 parameters.
glob:priv MAX_THREAD_LOOKUP_IDS: int = 40;

"""RFC 5322 Message-IDs are compared without their angle brackets or surrounding space."""
def normalizeMessageId(value: any = None) -> any {
    text: any = either(value, "");
    bare: any = rx_sub(text.trim(), BRACKETS, "");
    return bare.trim() or NULL;
}

"""Keep the parent, thread root, and newest ancestors within D1's 100 parameter limit."""
def selectThreadLookupIds(inReplyTo: any, references: any) -> list[str] {
    ids: list[str] = [];
    newest_first = [references[i] for i in range(len(references) - 1, 0, -1)];
    root_id = references[0] if len(references) else None;
    for (n, value) in enumerate([inReplyTo, root_id] + newest_first) {
        if n >= 2 and len(ids) >= MAX_THREAD_LOOKUP_IDS {
            break;
        }
        found = normalizeMessageId(value);
        if found and found not in ids {
            ids.append(found);
        }
    }
    return ids;
}
