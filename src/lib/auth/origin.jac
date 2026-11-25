def:priv origin_of(url: any) -> any {
    try {
        return new(globalThis.URL, url).origin;
    } except Exception {
        return None;
    }
}

"""The origin browsers use to reach this app. On Workers `request.url` is the public URL; the Node
server builds it from the bind address, so there it is APP_URL when set, otherwise the Host header,
https only when a trusted proxy (TRUST_PROXY) says so, as the realtime upgrade check does."""
def expectedRequestOrigin(request: any) -> any {
    (env, url) = (getNodeEnv(), new(globalThis.URL, request.url));
    if nil(env) or at(env, "MAILFLARE_RUNTIME") != "node" {
        return url.origin;
    }
    # A malformed APP_URL falls back to the request, so the check still compares something real.
    app = origin_of(at(env, "APP_URL", "").trim());
    if app {
        return app;
    }
    (h, trust) = (
        request.headers,
        at(env, "TRUST_PROXY", "").toLowerCase() in ["1", "true", "yes"],
    );
    host = either(h.get("host"), "").trim();
    https = trust and either(h.get("x-forwarded-proto"), "").split(",")[0].trim() == "https";
    return (origin_of(f"{'https:' if https else url.protocol}//{host}") if host else None)
        or url.origin;
}

"""Strict same-origin test for a state-changing request that authenticates by cookie:
`Sec-Fetch-Site: same-origin`, or an `Origin` equal to the expected origin. A missing Origin is not
enough (a sibling subdomain's form post or an old client may omit it), and `same-site` never is."""
def isSameOriginRequest(request: any, expectedOrigin: any = None) -> bool {
    expected = expectedRequestOrigin(request) if expectedOrigin is None else expectedOrigin;
    (site, origin) = (request.headers.get("Sec-Fetch-Site"), request.headers.get("Origin"));
    decided = site in ["same-origin", "cross-site", "same-site"];
    return site == "same-origin" if decided else (origin is not NULL and origin == expected);
}

"""Call only after session authentication. Bearer tokens are not sent automatically by browsers."""
def hasValidSessionMutationOrigin(request: any, expectedOrigin: any = None) -> bool {
    a: any = request.headers.get("Authorization");
    return bool(a and a.startsWith("Bearer ")) or isSameOriginRequest(request, expectedOrigin);
}
