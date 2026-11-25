"""
The DNS a self-hosted install needs when Mailflare does not manage the zone: "missing" until the
operator confirms, since the app cannot read their DNS; what the SMTP listener and a relay expect.
"""
async def getManualDomainDns(env: any, hostname: str) -> any {
    configured: any = at(globalThis.process.env, "MAIL_HOSTNAME") or "";
    host = configured.trim() or f"mail.{hostname}";
    mx = {"type": "MX", "name": hostname, "content": f"10 {host}", "ttl": 3600};
    spf = {"type": "TXT", "name": hostname, "content": f"v=spf1 a:{host} ~all", "ttl": 3600};
    dm = {"type": "TXT", "name": f"_dmarc.{hostname}", "content": "v=DMARC1; p=none", "ttl": 3600};
    routing = {"records": [], "missing": [mx, spf, dm], "status": "manual"};
    sending = dig(env, ["EMAIL", "configured"]) is True;
    return {"routing": routing, "sending": [], "sendingEnabled": sending};
}
