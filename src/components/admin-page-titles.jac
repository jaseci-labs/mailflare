# Titles shown in the phone top bar, keyed by exact path. Detail pages are absent on purpose: they
# keep their own in-page heading.
glob adminPageTitles: any = record({p[0]: p[1] for p in [pair.split("=") for pair in """
    /admin=admin.title /mailboxes=admin.nav.mailboxes /domains=admin.nav.domains
    /deliverability=admin.nav.deliverability /routing=admin.nav.routing /webhooks=admin.nav.webhooks
    /spam-filter=admin.nav.spamFilter /api-keys=admin.section.apiKeysTitle /general=admin.nav.general
    /agent=admin.nav.agent /accounts=admin.nav.accounts /activity=admin.nav.activity
    /backups=admin.nav.backups /branding=admin.nav.branding /licenses=admin.nav.licenses
    /ai-usage=admin.page.aiUsage
""".split()]});
