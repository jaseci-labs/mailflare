def:priv origin_of(url: any) -> any {
    try {
        return new(globalThis.URL, url).origin;
    } except Exception {
        return None;
    }
}

"""The origin browsers reach this app at: `request.url` on Workers; on Node (bind address) APP_URL,
else the Host header, https only if a trusted proxy (TRUST_PROXY) says so, like realtime-origin."""
def expectedRequestOrigin(request: any) -> any {
    env = getNodeEnv();
    url = new(globalThis.URL, request.url);
    if nil(env) or at(env, "MAILFLARE_RUNTIME") != "node" {
        return url.origin;
    }
    # A malformed APP_URL falls back to the request, so the check still compares something real.
    app = origin_of(at(env, "APP_URL", "").trim());
    if app {
        return app;
    }
    h: any = request.headers;
    trust = at(env, "TRUST_PROXY", "").toLowerCase() in ["1", "true", "yes"];
    host = either(h.get("host"), "").trim();
    https = trust and either(h.get("x-forwarded-proto"), "").split(",")[0].trim() == "https";
    # An empty Host makes an invalid URL, so it falls back too.
    return origin_of(f"{'https:' if https else url.protocol}//{host}") or url.origin;
}

"""Strict same-origin test for a cookie-authenticated mutation: `Sec-Fetch-Site: same-origin` or an
equal `Origin`. A missing Origin is not enough (sibling subdomains, old clients), nor `same-site`."""
def isSameOriginRequest(request: any, expectedOrigin: any = None) -> bool {
    expected = expectedRequestOrigin(request) if expectedOrigin is None else expectedOrigin;
    h: any = request.headers;
    site: any = h.get("Sec-Fetch-Site");
    if site == "same-origin" {
        return True;
    }
    if site == "cross-site" or site == "same-site" {
        return False;
    }
    origin: any = h.get("Origin");
    return origin is not NULL and origin is expected;
}

"""Call only after session authentication. Bearer tokens are not sent automatically by browsers."""
def hasValidSessionMutationOrigin(request: any, expectedOrigin: any = None) -> bool {
    a: any = request.headers.get("Authorization");
    return bool(a and a.startsWith("Bearer ")) or isSameOriginRequest(request, expectedOrigin);
}
