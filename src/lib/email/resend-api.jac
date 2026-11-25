"""The Resend REST API. A client is `{apiKey, baseUrl}`: where calls go and the key they carry."""

glob:priv RESEND_DEFAULT_BASE_URL: str = "https://api.resend.com",
          TRAILING_SLASHES: any = rx(r"\/+$"),
          # Until a send leaves the provider's queue its message_id can be a placeholder
          # (one compatible service answers <id@unsent.…> while `last_event` is "queued").
          UNSENT_EVENTS: list[str] = ["queued", "scheduled"],
          MESSAGE_ID_SHAPE: any = rx(r"^<[^<>\s]+@[^<>\s]+>$");

# Types that TypeScript modules still import by name.
type ResendClient = dict[str, str];

type ResendCapabilities = dict[str, bool];

type SentMessageIdPolling = dict[str, any];

"""An optional string setting of the environment, trimmed; None when unset."""
def:priv setting(env: any, name: str) -> any {
    value = at(env, name);
    return None if value is None else value.trim();
}

"""RESEND_BASE_URL points the Resend provider at a Resend-compatible API instead of api.resend.com."""
def resendBaseUrl(env: any) -> str {
    return rx_sub(setting(env, "RESEND_BASE_URL") or RESEND_DEFAULT_BASE_URL, TRAILING_SLASHES, "");
}

def resendClient(env: any, apiKey: str) -> dict[str, any] {
    return {"apiKey": apiKey, "baseUrl": resendBaseUrl(env)};
}

"""Resend accepts a custom Message-ID header; some Resend-compatible services refuse it.

RESEND_CUSTOM_MESSAGE_ID=false stops sending it, and the sent message's own Message-ID is read
back instead (see fetchSentMessageId).
"""
def resendSetsMessageId(env: any) -> bool {
    value = setting(env, "RESEND_CUSTOM_MESSAGE_ID");
    return value is None or value.toLowerCase() != "false";
}

"""Lower-cased names from RESEND_OMIT_HEADERS (comma-separated).

Headers a Resend-compatible service refuses, such as Auto-Submitted, left out of sends.
"""
def resendOmittedHeaders(env: any) -> any {
    listed: any = at(env, "RESEND_OMIT_HEADERS", "");
    names = [part.trim().toLowerCase() for part in globalThis.String.prototype.split.call(listed, ",")];
    return new(globalThis.Set, [name for name in names if name]);
}

def:priv bearer(client: any) -> dict[str, str] {
    return {"Authorization": f"Bearer {client['apiKey']}"};
}

"""The JSON body of a response, null when it has none."""
async def:priv json_of(response: any) -> any {
    try {
        return await response.json();
    } except Exception {
        return NULL;
    }
}

"""`body?.name` of a parsed JSON body that may be null."""
def:priv field(body: any, name: str) -> any {
    return None if nil(body) else body[name];
}

async def:priv read_sent_email(client: any, emailId: str) -> any {
    try {
        response = await globalThis.fetch(
            f"{client['baseUrl']}/emails/{globalThis.encodeURIComponent(emailId)}",
            {"headers": bearer(client)}
        );
    } except Exception {
        return None;
    }
    if not response or not response.ok {
        return None;
    }
    body = await json_of(response);
    message_id = field(body, "message_id");
    value = message_id.trim() if isinstance(message_id, str) else "";
    return {
        "messageId": value if MESSAGE_ID_SHAPE.test(value) else NULL,
        "unsent": globalThis.String(field(body, "last_event")) in UNSENT_EVENTS
    };
}

def:priv pause(ms: any) -> any {
    return new(
        globalThis.Promise,
        lambda (resolve: any) -> any { globalThis.setTimeout(resolve, ms) }
    );
}

"""The Message-ID the provider gave a sent email, read from `GET /emails/{id}`.

It is there once the email has left the queue. Resend reports none; some compatible services
do. Polls briefly (the ID arrives within seconds), else null.
"""
async def fetchSentMessageId(client: any, emailId: str, polling: any = None) -> any {
    (attempts, delay, sleep) = (6, 1000, pause)
        if polling is None
        else (polling.attempts, polling.delayMs, polling.sleep);
    attempt = 1;
    while attempt <= attempts {
        email = await read_sent_email(client, emailId);
        if not email {
            return NULL;
        }
        if not email["unsent"] {
            return email["messageId"];
        }
        if attempt < attempts {
            await sleep(delay);
        }
        attempt += 1;
    }
    return NULL;
}

obj ResendRestrictedKeyError(globalThis.Error) {
    def init() {
        super.init(
            "This Resend key can only send mail, so Mailflare cannot add or check domains. Add the domain in the Resend dashboard, or use a full-access key."
        );
    }
}

async def:priv request(client: any, path: str, options: any = None) -> any {
    headers = merged(bearer(client), {"Content-Type": "application/json"}, at(options, "headers", {}) if options else {});
    response = await globalThis.fetch(
        f"{client['baseUrl']}{path}",
        merged(options or {}, {"headers": headers})
    );
    body = await json_of(response);
    if not response.ok {
        # A send-only key cannot manage domains; say so instead of a bare 401.
        if field(body, "name") == "restricted_api_key" {
            raise new(ResendRestrictedKeyError);
        }
        detail = either(field(body, "message"), f"request failed ({globalThis.String(response.status)})");
        raise new(globalThis.Error, f"Resend: {detail}");
    }
    return body;
}

def:priv json(value: any) -> str {
    return globalThis.JSON.stringify(value);
}

def:priv domain_path(domain_id: str) -> str {
    return f"/domains/{globalThis.encodeURIComponent(domain_id)}";
}

def:priv switch(on: any) -> str {
    return "enabled" if on else "disabled";
}

async def findResendDomain(client: any, hostname: any) -> any {
    listing = await request(client, "/domains");
    for domain in listing.data {
        if domain.name.toLowerCase() == hostname.toLowerCase() {
            return await getResendDomain(client, domain.id);
        }
    }
    return NULL;
}

async def getResendDomain(client: any, domain_id: str) -> any {
    return await request(client, domain_path(domain_id));
}

async def createResendDomain(client: any, hostname: str, capabilities: any = None) -> any {
    caps = {"sending": "enabled", "receiving": "disabled"}
        if capabilities is None
        else {
            "sending": switch(capabilities["sending"]),
            "receiving": switch(capabilities["receiving"])
        };
    return await request(
        client,
        "/domains",
        {"method": "POST", "body": json({"name": hostname, "capabilities": caps})}
    );
}

"""Turns a capability on without touching the other (omitted fields keep their value)."""
async def updateResendCapabilities(client: any, domain_id: str, capabilities: any) -> None {
    caps = {
        name: switch(capabilities[name])
        for name in ["sending", "receiving"]
        if capabilities[name] is not None
    };
    await request(client, domain_path(domain_id), {"method": "PATCH", "body": json({"capabilities": caps})});
}

async def listResendWebhooks(client: any) -> any {
    return (await request(client, "/webhooks")).data;
}

async def createResendWebhook(client: any, endpoint: str, events: any = None) -> any {
    wanted = ["email.received"] if events is None else events;
    return await request(
        client,
        "/webhooks",
        {"method": "POST", "body": json({"endpoint": endpoint, "events": wanted})}
    );
}

async def deleteResendWebhook(client: any, webhook_id: str) -> None {
    await request(client, f"/webhooks/{globalThis.encodeURIComponent(webhook_id)}", {"method": "DELETE"});
}

async def getReceivedEmail(client: any, email_id: str) -> any {
    return await request(client, f"/emails/receiving/{globalThis.encodeURIComponent(email_id)}");
}

async def verifyResendDomain(client: any, domain_id: str) -> None {
    await request(client, domain_path(domain_id) + "/verify", {"method": "POST"});
}

"""A key is valid if Resend accepts it at all.

Send-only keys are rejected by the domains endpoint with `restricted_api_key`, which still
means the key works.
"""
async def checkResendKey(client: any) -> dict[str, bool] {
    response = await globalThis.fetch(f"{client['baseUrl']}/domains", {"headers": bearer(client)});
    if response.ok {
        return {"valid": True, "canManageDomains": True};
    }
    body = await json_of(response);
    restricted = response.status == 401 and field(body, "name") == "restricted_api_key";
    return {"valid": restricted, "canManageDomains": False};
}

async def deleteResendDomain(client: any, domain_id: str) -> None {
    await request(client, domain_path(domain_id), {"method": "DELETE"});
}
