"""The mailbox a local part delivers to: no `+tag`, no dots, lower case."""
def normalizeRecipientLocalPart(localPart: str) -> str {
    return localPart.split("+")[0].replace(".", "").lower();
}

def parseRecipientAddress(address: str) -> any {
    parsed = parseAddress(address);
    if not parsed {
        return NULL;
    }
    local_part = normalizeRecipientLocalPart(parsed["local"]);
    if not local_part {
        return NULL;
    }
    return record({
        "original": address,
        "localPart": local_part,
        "domain": parsed["domain"],
        "normalizedAddress": f"{local_part}@{parsed['domain']}",
    });
}
