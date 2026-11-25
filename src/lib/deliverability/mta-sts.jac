"""
MTA-STS (RFC 8461) policy text and the host guard. Pure and framework free so the Worker, the Node server and the
Next route share it. Nothing here reads the request beyond the host name and path.
"""

# max_age is one day to one year, in seconds. RFC 8461 allows up to 31,557,600.
glob MTA_STS_LIMITS: any = globalThis.Object.freeze(
         record({"minMaxAge": 86400, "maxMaxAge": 31557600, "defaultMaxAge": 604800, "maxMx": 20})
     ),
     MTA_STS_HOST_PREFIX: str = "mta-sts.",
     MTA_STS_POLICY_PATH: str = "/.well-known/mta-sts.txt";

type MtaStsMode = str;

glob:priv LABEL: str = "[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?",
          HOSTNAME: any = rx(f"^{LABEL}(?:\\.{LABEL})*$"),
          MX_PATTERN: any = rx(f"^(?:\\*\\.)?{LABEL}(?:\\.{LABEL})+$"),
          ROOT_DOT: any = rx(r"\.$"),
          PORT: any = rx(r":\d+$"),
          POLICY_ID: any = rx(r"^\d{14}$");

def:priv rootless(hostname: any) -> str {
    return rx_sub(hostname.toLowerCase(), ROOT_DOT, "");
}

"""The managed domain a request host asks about (`mta-sts.<domain>`), or null for any other host or a malformed one."""
def mtaStsHostDomain(hostname: str) -> any {
    host = rootless(hostname);
    if not host.startswith(MTA_STS_HOST_PREFIX) or len(host) > 253 {
        return NULL;
    }
    domain = host[len(MTA_STS_HOST_PREFIX):];
    return domain if HOSTNAME.test(domain) else NULL;
}

"""A host name or Host header value without port: `Example.COM:8080` becomes `example.com`."""
def hostnameOf(hostHeader: any) -> str {
    return rx_sub(rx_sub(hostHeader.trim().toLowerCase(), PORT, ""), ROOT_DOT, "");
}

"""True for any `mta-sts.*` host name, valid or not: such a host never gets the application."""
def isMtaStsHost(hostname: str) -> bool {
    return rootless(hostname).startswith(MTA_STS_HOST_PREFIX);
}

def:priv plain_text(body: str, status: int, headers: dict[str, str] = {}) -> any {
    return new(
        globalThis.Response,
        body,
        record({
            "status": status,
            "headers": merged({"Content-Type": "text/plain; charset=utf-8"}, headers),
        }),
    );
}

"""
Keeps the full application off `mta-sts.*` hosts: on such a host only GET and HEAD of the policy path continue (to the
route, which answers for configured domains only); any other path is a 404 and any other method a 405. Returns null when
the request should continue. A Workers Custom Domain or a reverse proxy routes the whole host to the app, so without this
the login page and the APIs would be served there too.
"""
def guardMtaStsHost(request: any) -> any {
    if not isMtaStsHost(request["hostname"]) {
        return NULL;
    }
    if request["pathname"] != MTA_STS_POLICY_PATH {
        return plain_text("Not found", 404);
    }
    if request["method"] not in ["GET", "HEAD"] {
        return plain_text("Method not allowed", 405, {"Allow": "GET, HEAD"});
    }
    return NULL;
}

"""Lower-cased, de-duplicated, sorted MX host patterns, or null when any entry is not a plain host name (a leading `*.` is allowed)."""
def normalizeMx(hosts: any) -> any {
    if not globalThis.Array.isArray(hosts) {
        return NULL;
    }
    clean: list[str] = [];
    for host in hosts {
        value = rx_sub(host.trim().toLowerCase(), ROOT_DOT, "") if isinstance(host, str) else "";
        if len(value) > 253 or not MX_PATTERN.test(value) {
            return NULL;
        }
        if value not in clean {
            clean.append(value);
        }
    }
    return sorted(clean);
}

"""The value when it is a whole number of seconds inside the allowed range, the default when undefined, otherwise null."""
def parseMaxAge(value: any = None) -> any {
    if value is None {
        return MTA_STS_LIMITS.defaultMaxAge;
    }
    return value
        if globalThis.Number.isInteger(value)
            and MTA_STS_LIMITS.minMaxAge <= value <= MTA_STS_LIMITS.maxMaxAge
        else NULL;
}

"""The policy file: CRLF lines, MX hosts sorted. Throws on anything that is not a valid mode, MX list or max_age, so a bad value can never reach the file."""
def buildMtaStsPolicy(policy: any) -> str {
    if policy["mode"] not in ["none", "testing", "enforce"] {
        raise new(globalThis.Error, "Invalid MTA-STS mode");
    }
    mx = normalizeMx(policy["mx"]);
    if not mx or len(mx) > MTA_STS_LIMITS.maxMx {
        raise new(
            globalThis.Error, f"Invalid MTA-STS mx list (1 to {MTA_STS_LIMITS.maxMx} host names)"
        );
    }
    if parseMaxAge(policy["maxAge"]) is NULL {
        raise new(globalThis.Error, "Invalid MTA-STS max_age");
    }
    lines = ["version: STSv1", f"mode: {policy['mode']}"]
        + [f"mx: {host}" for host in mx]
        + [f"max_age: {policy['maxAge']}", ""];
    return "\r\n".join(lines);
}

"""A UTC time as YYYYMMDDHHMMSS."""
def:priv stamp_of(moment: any) -> str {
    parts = [
        (moment.getUTCFullYear(), 4),
        (moment.getUTCMonth() + 1, 2),
        (moment.getUTCDate(), 2),
        (moment.getUTCHours(), 2),
        (moment.getUTCMinutes(), 2),
        (moment.getUTCSeconds(), 2),
    ];
    return "".join([globalThis.String(value).padStart(width, "0") for (value, width) in parts]);
}

"""
The `id` of the `_mta-sts` TXT record: the UTC time as YYYYMMDDHHMMSS, and always greater than `previous`, so a change
made in the same second (or after the clock moved back) still gets a new id and receivers fetch the policy again.
"""
def nextPolicyId(now: any, previous: any = None) -> str {
    stamp = stamp_of(now);
    if not previous or not POLICY_ID.test(previous) or previous < stamp {
        return stamp;
    }
    part = lambda (start: int, end: int) -> any { globalThis.Number(previous.slice(start, end)) };
    return stamp_of(
        new(
            globalThis.Date,
            globalThis.Date.UTC(
                part(0, 4), part(4, 6) - 1, part(6, 8), part(8, 10), part(10, 12), part(12, 14) + 1
            ),
        ),
    );
}
