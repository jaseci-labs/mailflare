"""The Resend REST API. A client is `{apiKey, baseUrl}`: where calls go and the key they carry."""

# Until a send leaves the provider's queue its message_id can be a placeholder
# (one compatible service answers <id@unsent.…> while `last_event` is "queued").
glob:priv UNSENT_EVENTS: list[str] = ["queued", "scheduled"],
          MESSAGE_ID_SHAPE: any = rx(r"^<[^<>\s]+@[^<>\s]+>$"),
          RESTRICTED: str = "This Resend key can only send mail, so Mailflare cannot add or check domains. Add the domain in the Resend dashboard, or use a full-access key.";
type ResendClient = any;
type ResendCapabilities = any;

# RESEND_BASE_URL points the Resend provider at a Resend-compatible API instead of api.resend.com.
def resendBaseUrl(env: any) -> str {
    url: any = at(env, "RESEND_BASE_URL", "");
    return rx_sub(url.trim() or "https://api.resend.com", rx(r"\/+$"), "");
}

def resendClient(env: any, apiKey: str) -> any {
    return record({"apiKey": apiKey, "baseUrl": resendBaseUrl(env)});
}

# Some Resend-compatible services refuse a custom Message-ID: RESEND_CUSTOM_MESSAGE_ID=false stops
# sending it, and fetchSentMessageId reads the sent message's own back instead.
def resendSetsMessageId(env: any) -> bool {
    return at(env, "RESEND_CUSTOM_MESSAGE_ID", "").trim().toLowerCase() != "false";
}

# Lower-cased RESEND_OMIT_HEADERS (comma-separated): headers a compatible service refuses.
def resendOmittedHeaders(env: any) -> any {
    names = globalThis.String.prototype.split.call(at(env, "RESEND_OMIT_HEADERS", ""), ",");
    return new(globalThis.Set, [n.trim().toLowerCase() for n in names if n.trim()]);
}

def:priv bearer(client: any) -> any {
    return record({"Authorization": f"Bearer {client['apiKey']}"});
}

def:priv enc(s: str) -> str {
    return globalThis.encodeURIComponent(s);
}

def:priv json_of(response: any) -> any {
    return response.json().catch(lambda (e: any) -> any { NULL });
}

def:priv pause(ms: any) -> any {
    return new(globalThis.Promise, lambda (done: any) -> any { globalThis.setTimeout(done, ms) });
}

# The Message-ID the provider gave a sent email, from `GET /emails/{id}` once it left the queue.
# Resend reports none; some compatible services do. Polls briefly, else null.
async def fetchSentMessageId(client: any, emailId: str, polling: any = None) -> any {
    p = polling or {"attempts": 6, "delayMs": 1000, "sleep": pause};
    url = f"{client['baseUrl']}/emails/{enc(emailId)}";
    for attempt in range(1, p["attempts"] + 1) {
        try {
            res = await globalThis.fetch(url, {"headers": bearer(client)});
        } except Exception {
            return NULL;
        }
        body = await json_of(res) if res.ok else NULL;
        if not res.ok or globalThis.String(dig(body, ["last_event"])) not in UNSENT_EVENTS {
            mid = dig(body, ["message_id"]);
            v = mid.trim() if res.ok and isinstance(mid, str) else "";
            return v if MESSAGE_ID_SHAPE.test(v) else NULL;
        }
        if attempt < p["attempts"] {
            await p["sleep"](p["delayMs"]);
        }
    }
    return NULL;
}

obj ResendRestrictedKeyError(globalThis.Error) {
    def init {
        super.init(RESTRICTED);
    }
}

async def:priv request(client: any, path: str, method: any = None, body: any = None) -> any {
    pairs = [("method", method), ("body", globalThis.JSON.stringify(body))];
    headers = merged(bearer(client), {"Content-Type": "application/json"});
    init = merged({k: v for (k, v) in pairs if v is not None}, {"headers": headers});
    res = await globalThis.fetch(f"{client['baseUrl']}{path}", init);
    body = await json_of(res);
    if not res.ok {
        # A send-only key cannot manage domains; say so instead of a bare 401.
        if dig(body, ["name"]) == "restricted_api_key" {
            raise new(ResendRestrictedKeyError);
        }
        why = either(dig(body, ["message"]), f"request failed ({globalThis.String(res.status)})");
        raise new(globalThis.Error, f"Resend: {why}");
    }
    return body;
}

def:priv enabled(on: any) -> str {
    return "enabled" if on else "disabled";
}

async def findResendDomain(client: any, hostname: any) -> any {
    for d in (await request(client, "/domains")).data {
        if d.name.toLowerCase() == hostname.toLowerCase() {
            return await getResendDomain(client, d.id);
        }
    }
    return NULL;
}

async def getResendDomain(client: any, domain_id: str) -> any {
    return await request(client, f"/domains/{enc(domain_id)}");
}

async def createResendDomain(client: any, hostname: str, capabilities: any = None) -> any {
    c = capabilities or {"sending": True, "receiving": False};
    caps = {"sending": enabled(c["sending"]), "receiving": enabled(c["receiving"])};
    return await request(client, "/domains", "POST", {"name": hostname, "capabilities": caps});
}

# Turns a capability on without touching the other (omitted fields keep their value).
async def updateResendCapabilities(client: any, domain_id: str, c: any) {
    on = {k: enabled(c[k]) for k in ["sending", "receiving"] if c[k] is not None};
    await request(client, f"/domains/{enc(domain_id)}", "PATCH", {"capabilities": on});
}

async def listResendWebhooks(client: any) -> any {
    return (await request(client, "/webhooks")).data;
}

async def createResendWebhook(client: any, endpoint: str, events: any = None) -> any {
    wanted = ["email.received"] if events is None else events;
    return await request(client, "/webhooks", "POST", {"endpoint": endpoint, "events": wanted});
}

async def deleteResendWebhook(client: any, webhook_id: str) {
    await request(client, f"/webhooks/{enc(webhook_id)}", "DELETE");
}

async def getReceivedEmail(client: any, email_id: str) -> any {
    return await request(client, f"/emails/receiving/{enc(email_id)}");
}

async def verifyResendDomain(client: any, domain_id: str) {
    await request(client, f"/domains/{enc(domain_id)}/verify", "POST");
}

# Valid if Resend accepts the key at all: the domains endpoint rejects a send-only key with
# `restricted_api_key`, which still means the key works.
async def checkResendKey(client: any) -> any {
    res = await globalThis.fetch(f"{client['baseUrl']}/domains", {"headers": bearer(client)});
    if res.ok {
        return {"valid": True, "canManageDomains": True};
    }
    restricted = res.status == 401 and dig(await json_of(res), ["name"]) == "restricted_api_key";
    return {"valid": restricted, "canManageDomains": False};
}

async def deleteResendDomain(client: any, domain_id: str) {
    await request(client, f"/domains/{enc(domain_id)}", "DELETE");
}
