"""A user's primary mailbox is the one at their account address. It carries the account identity:
its name and avatar are the profile's, and editing either side keeps both in step. Every other
personal mailbox owns its own display name and avatar, so renaming one never touches its siblings."""
def mailboxAddress(mailbox: any) -> str {
    address: any = globalThis.String(mailbox["localPart"])
        + "@"
        + globalThis.String(mailbox["hostname"]);
    return address.trim().toLowerCase();
}

def isPrimaryMailbox(mailbox: any, accountEmail: any = None) -> bool {
    return bool(accountEmail) and mailboxAddress(mailbox) == accountEmail.trim().toLowerCase();
}

"""True when the mailbox's name and avatar come from the account profile."""
def tracksAccountIdentity(mailbox: any, accountEmail: any = None) -> bool {
    return mailbox["type"] == "personal" and isPrimaryMailbox(mailbox, accountEmail);
}

"""The name to show for a mailbox, before falling back to its local part."""
def resolveMailboxDisplayName(mailbox: any, accountEmail: any, accountName: any) -> any {
    return accountName if tracksAccountIdentity(mailbox, accountEmail) else mailbox["displayName"];
}

"""The avatar key to serve for a mailbox."""
def resolveMailboxAvatarKey(mailbox: any, accountEmail: any, accountAvatarKey: any) -> any {
    return accountAvatarKey
        if tracksAccountIdentity(mailbox, accountEmail)
        else mailbox["avatarKey"];
}
