"""Scopes an API key can be granted. Kept free of server-only imports so the dashboard's
key-creation form can import it without pulling in bcrypt. Administrative scopes are issued
separately from personal mail keys."""
glob API_KEY_SCOPES: list[str] = ["send", "read", "jmap", "calendar:read", "calendar:write"],
     ADMIN_API_KEY_SCOPES: list[str] = ["domains", "accounts", "mailboxes", "storage"];

"""What an app password (`api_keys.kind = 'app'`) can be limited to. Kept apart from `API_KEY_SCOPES`
so a general API key can never carry `dav`, `imap` or `submission` (`dav` is CalDAV and CardDAV together)."""
glob APP_PASSWORD_PROTOCOLS: list[str] = ["jmap", "dav", "imap", "submission"];

type ApiKeyScope = any;

type AppPasswordScope = any;
