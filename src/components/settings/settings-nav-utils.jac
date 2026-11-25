"""Settings pages from `path:labelKey` words (the key defaults to the path)."""
def:priv pages(spec: str) -> list[any] {
    pairs = [(p.split(":")[0], p.split(":")[-1]) for p in spec.split()];
    return [{"href": f"/settings/{h}", "labelKey": f"settings.nav.{k}"} for (h, k) in pairs];
}

glob settingsNavSections: any = record([
    {
        "labelKey": "settings.nav.settings",
        "items": pages("account inbox security api-keys:apiKeys app-passwords:appPasswords rules"),
    },
    {
        "labelKey": "settings.nav.mailbox",
        "items": [
            {
                "href": "/settings/mailboxes",
                "labelKey": "admin.nav.mailboxes",
                "requiresMailboxAccess": True,
            },
            *pages("import export"),
        ],
    },
]);

def isActiveSettingsPath(pathname: str, href: str) -> bool {
    return pathname == href or pathname.startswith(f"{href}/");
}
