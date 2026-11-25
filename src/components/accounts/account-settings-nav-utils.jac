glob accountSettingsNavItems: any = record([
    {"segment": s, "labelKey": f"accountSettings.{s or 'details'}"}
    for s in ["", "password", "permissions", "mailboxes"]
]);

def getAccountSettingsHref(accountId: any, segment: any) -> str {
    return f"/accounts/{accountId}" + (f"/{segment}" if segment else "");
}

def isActiveAccountSettingsPath(pathname: any, href: any) -> bool {
    return pathname == href;
}
