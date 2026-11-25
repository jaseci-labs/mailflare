glob:priv ROUTES: list[any] = [r.split("=") for r in """
    /settings=settings.nav.settings /admin=admin.title /mailboxes=admin.nav.mailboxes
    /domains=admin.nav.domains /routing=admin.nav.routing /webhooks=admin.nav.webhooks
    /spam-filter=admin.nav.spamFilter /api-keys=admin.nav.apiKeys /general=admin.nav.general
    /agent=admin.nav.agent /accounts=admin.nav.accounts /activity=admin.nav.activity
    /backups=admin.nav.backups /branding=admin.nav.branding /licenses=admin.nav.licenses
    /ai-usage=aiUsage.title /calendar=account.calendar /booking=booking.title /drive=drive.title
    /contacts=navigation.contacts /subscriptions=navigation.subscriptions /compose=compose.pageTitle
""".split()] + [[i["href"], i["labelKey"]] for s in settingsNavSections for i in s["items"]];

"""The title of the longest route that is `pathname` or one of its parents; the first such wins a tie."""
def getRouteTitleKey(pathname: str) -> any {
    (best, size) = (NULL, -1);
    for (path, key) in ROUTES {
        if (pathname == path or pathname.startswith(path + "/")) and len(path) > size {
            (best, size) = (key, len(path));
        }
    }
    return best;
}
