# MTA-STS (RFC 8461) policy text and host guard. max_age: a day to a year (the RFC's maximum).
glob:priv AGES: any = {"minMaxAge": 86400, "maxMaxAge": 31557600, "defaultMaxAge": 604800},
          LABEL: str = "[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?";

glob MTA_STS_LIMITS: any = globalThis.Object.freeze(record({**AGES, "maxMx": 20})),
     MTA_STS_HOST_PREFIX: str = "mta-sts.",
     MTA_STS_POLICY_PATH: str = "/.well-known/mta-sts.txt";

type MtaStsMode = str;

def:priv rootless(hostname: any) -> str {
    return rx_sub(hostname.toLowerCase(), rx(r"\.$"), "");
}

"""The managed domain a request host asks about (`mta-sts.<domain>`), or null for any other host."""
def mtaStsHostDomain(hostname: str) -> any {
    host = rootless(hostname);
    domain = host[len(MTA_STS_HOST_PREFIX):];
    named = rx(f"^{LABEL}(?:\\.{LABEL})*$").test(domain);
    return domain if host.startswith(MTA_STS_HOST_PREFIX) and len(host) <= 253 and named else NULL;
}

"""A host name or Host header value without port: `Example.COM:8080` becomes `example.com`."""
def hostnameOf(hostHeader: any) -> str {
    return rootless(rx_sub(hostHeader.trim(), rx(r":\d+$"), ""));
}

"""True for any `mta-sts.*` host name, valid or not: such a host never gets the application."""
def isMtaStsHost(hostname: str) -> bool {
    return rootless(hostname).startswith(MTA_STS_HOST_PREFIX);
}

"""Keeps the app off `mta-sts.*` hosts: only GET and HEAD of the policy path continue (null)."""
def guardMtaStsHost(request: any) -> any {
    # A Custom Domain or reverse proxy routes the whole host to the app; it must not serve the rest.
    gone = request["pathname"] != MTA_STS_POLICY_PATH;
    if not isMtaStsHost(request["hostname"]) or not gone and request["method"] in ["GET", "HEAD"] {
        return NULL;
    }
    allow: dict[str, str] = {} if gone else {"Allow": "GET, HEAD"};
    hs = {"Content-Type": "text/plain; charset=utf-8", **allow};
    init = record({"status": 404 if gone else 405, "headers": record(hs)});
    return new(globalThis.Response, "Not found" if gone else "Method not allowed", init);
}

"""Lower-cased, de-duplicated, sorted MX hosts (a leading `*.` allowed), or null if one is not."""
def normalizeMx(hosts: any) -> any {
    ok = globalThis.Array.isArray(hosts);
    mx = rx(f"^(?:\\*\\.)?{LABEL}(?:\\.{LABEL})+$");
    clean = [rootless(h.trim()) if isinstance(h, str) else "" for h in (hosts if ok else [])];
    valid = ok and all([len(v) <= 253 and mx.test(v) for v in clean]);
    return sorted(set(clean)) if valid else NULL;
}

"""The value when a whole number of seconds in range, the default when undefined, else null."""
def parseMaxAge(value: any = None) -> any {
    ok = whole(value, AGES["minMaxAge"], AGES["maxMaxAge"]);
    return AGES["defaultMaxAge"] if value is None else value if ok else NULL;
}

"""The policy file: CRLF lines, MX hosts sorted. Throws on any invalid mode, MX list or max_age."""
def buildMtaStsPolicy(policy: any) -> str {
    (mode, mx, top) = (policy["mode"], normalizeMx(policy["mx"]), MTA_STS_LIMITS.maxMx);
    why = "mode" if mode not in ["none", "testing", "enforce"] else "";
    why = why or ("" if mx and len(mx) <= top else f"mx list (1 to {top} host names)");
    why = why or ("max_age" if parseMaxAge(policy["maxAge"]) is NULL else "");
    if why {
        raise new(globalThis.Error, f"Invalid MTA-STS {why}");
    }
    hosts = [f"mx: {h}" for h in mx] + ["max_age: " + globalThis.String(policy["maxAge"]), ""];
    return "\r\n".join(["version: STSv1", f"mode: {mode}", *hosts]);
}

"""A UTC time as YYYYMMDDHHMMSS."""
def:priv stamp_of(t: any) -> str {
    hms = [t.getUTCDate(), t.getUTCHours(), t.getUTCMinutes(), t.getUTCSeconds()];
    s = [globalThis.String(p).padStart(2, "0") for p in [t.getUTCMonth() + 1, *hms]];
    return globalThis.String(t.getUTCFullYear()).padStart(4, "0") + "".join(s);
}

"""The `_mta-sts` TXT record's `id`: the UTC time as YYYYMMDDHHMMSS, always above `previous`."""
def nextPolicyId(now: any, previous: any = None) -> str {
    stamp = stamp_of(now);
    if not previous or not rx(r"^\d{14}$").test(previous) or previous < stamp {
        return stamp;
    }
    # Even in the same second or after the clock moved back, so receivers fetch the policy again.
    p = [globalThis.Number(previous.slice(i, i + 2)) for i in range(0, 14, 2)];
    when = globalThis.Date.UTC(p[0] * 100 + p[1], p[2] - 1, p[3], p[4], p[5], p[6] + 1);
    return stamp_of(new(globalThis.Date, when));
}
