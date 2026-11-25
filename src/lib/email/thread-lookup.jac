# RFC 5322 Message-IDs are compared without their angle brackets or surrounding space.
def normalizeMessageId(value: any = None) -> any {
    bare: any = rx_sub(either(value, "").trim(), rx(r"^<|>$", "g"), "");
    return bare.trim() or NULL;
}

# Parent, thread root and newest ancestors, at most 40: 1 + 2 variants each fits D1's 100 params.
def selectThreadLookupIds(inReplyTo: any, references: any) -> list[str] {
    ids: list[str] = [];
    newest_first = [references[i] for i in range(len(references) - 1, 0, -1)];
    for (n, value) in enumerate([inReplyTo, first(references)] + newest_first) {
        if n >= 2 and len(ids) >= 40 {
            break;
        }
        found = normalizeMessageId(value);
        if found and found not in ids {
            ids.append(found);
        }
    }
    return ids;
}
