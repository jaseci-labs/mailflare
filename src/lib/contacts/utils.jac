def getContactId(userId: str, email: any) -> str {
    return f"{userId}:{email.trim().toLowerCase()}";
}

def getContactNameFromAddress(address: str) -> any {
    name: any = parseEmailAddressParts(address)["name"];
    name = name.trim() if name else NULL;
    return name if name and name != normalizeEmailAddress(address) else NULL;
}

def getDisplayNameForAddress(address: str, contactName: any = None) -> str {
    return (contactName.trim() if contactName else "") or getEmailDisplayName(address);
}

"""
The label for one party of a message, sender or recipient. A name the user set on the contact (or imported
from the address book) wins, then the message's own header name, then a name learned from other mail for the
same address. A shared address such as a recruiting no-reply can carry a different company name on every
message, so the header must beat the contact's last-learned name.
"""
def getPartyDisplayName(address: str, contact: any = None) -> any {
    (name, source) = (at(contact, "displayName"), at(contact, "source"))
        if contact
        else (NULL, NULL);
    contactName = (name.trim() if name else "") or NULL;
    if source in ["manual", "import"] and contactName {
        return contactName;
    }
    return either(getContactNameFromAddress(address), contactName);
}
