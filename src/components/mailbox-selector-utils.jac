glob:priv ADMIN_PREFIXES: list[str] = "/mailboxes /domains /api-keys /webhooks /activity /backups".split();

def getMailboxAddress(mailbox: any) -> str {
    return f"{mailbox['localPart']}@{mailbox['hostname']}";
}

def getMailboxName(mailbox: any) -> any {
    return either(mailbox["displayName"], mailbox["localPart"]);
}

def getAccountInitial(value: any) -> str {
    return value.trim().slice(0, 1).toUpperCase() or "M";
}

def isAdminPath(pathname: any) -> bool {
    return pathname == "/admin" or any([pathname.startswith(p) for p in ADMIN_PREFIXES]);
}
