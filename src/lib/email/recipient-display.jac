# `address`: mailbox only. `full`: Name <mailbox> when the header has a display name.
type RecipientAddressStyle = str;

def:priv trimmed(value: any) -> str {
    return value.trim() if value else "";
}

def:priv display_name(item: str) -> str {
    return trimmed(parseEmailAddressParts(item)["name"]);
}

def formatRecipientAddress(item: str, style: str) -> str {
    address = trimmed(getEmailAddress(item));
    if not address {
        return trimmed(item);
    }
    name = display_name(item) if style == "full" else "";
    return f"{name} <{address}>" if name else address;
}

def formatRecipientAddressList(value: any, style: str) -> str {
    return ", ".join([
        formatRecipientAddress(item, style)
        for item in splitEmailAddressList(value or "")
    ]);
}

"""Name to store on a contact. Never the formatted Name <mailbox> label."""
def recipientContactName(item: str) -> str {
    return display_name(item) or trimmed(getEmailAddress(item)) or trimmed(item);
}
