def:priv trimmed(value: any) -> any {
    return None if nil(value) else value.trim();
}

"""The origin browsers use to reach this app, which a same-origin request must carry.

On Workers `request.url` is the public URL. On the self-hosted Node server Next builds it from the
bind address (`http://0.0.0.0:3000`), so the expected origin is APP_URL when set, otherwise the
Host header, with https only when a trusted reverse proxy (TRUST_PROXY) says so, exactly as the
realtime upgrade check does (server/runtime/realtime-origin.ts)."""
def expectedRequestOrigin(request: any) -> str {
    env = getNodeEnv();
    url = new(globalThis.URL, request.url);
    if nil(env) or at(env, "MAILFLARE_RUNTIME") != "node" {
        return url.origin;
    }
    appUrl = trimmed(at(env, "APP_URL"));
    if appUrl {
        try {
            return new(globalThis.URL, appUrl).origin;
        } except Exception {
            # A malformed APP_URL falls back to the request, so the check still compares something real.
        }
    }
    host = trimmed(request.headers.get("host"));
    trustProxy = at(env, "TRUST_PROXY", "").toLowerCase() in ["1", "true", "yes"];
    forwarded: any = request.headers.get("x-forwarded-proto") if trustProxy else None;
    forwardedProto = None if nil(forwarded) else trimmed(forwarded.split(",")[0]);
    protocol = "https:" if forwardedProto == "https" else url.protocol;
    try {
        return new(globalThis.URL, f"{protocol}//{host}").origin if host else url.origin;
    } except Exception {
        return url.origin;
    }
}

"""Strict same-origin test for a state-changing browser request that authenticates by cookie.
The request must prove it comes from this app's own pages: `Sec-Fetch-Site: same-origin`, or an
`Origin` equal to the expected origin. A missing Origin is not accepted on its own (a form post
from a sibling subdomain or an old client may omit it), and `same-site` never is."""
def isSameOriginRequest(request: any, expectedOrigin: any = None) -> bool {
    if expectedOrigin is None {
        expectedOrigin = expectedRequestOrigin(request);
    }
    fetchSite = request.headers.get("Sec-Fetch-Site");
    if fetchSite == "same-origin" {
        return True;
    }
    if fetchSite in ["cross-site", "same-site"] {
        return False;
    }
    origin = request.headers.get("Origin");
    return origin is not NULL and origin == expectedOrigin;
}

"""Call only after session authentication. Bearer tokens are not sent automatically by browsers."""
def hasValidSessionMutationOrigin(request: any, expectedOrigin: any = None) -> bool {
    authorization: any = request.headers.get("Authorization");
    return (not nil(authorization) and authorization.startsWith("Bearer "))
        or isSameOriginRequest(request, expectedOrigin);
}
