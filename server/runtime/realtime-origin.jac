def:priv header(headers: any, name: str) -> any {
    v: any = headers[name];
    return first(v) if globalThis.Array.isArray(v) else v;
}

"""Like worker.ts, refuse realtime upgrades from another Origin: the SameSite=Lax cookie rides same-site,
cross-origin handshakes. Expected: APP_URL, else the Host header (https if a trusted proxy says so)."""
def isRealtimeOriginAllowed(headers: any, options: any) -> bool {
    proto: any = header(headers, "x-forwarded-proto") if options["trustProxy"] else None;
    scheme = "https" if not nil(proto) and proto.split(",")[0].trim() == "https" else "http";
    app: any = options["appUrl"];
    try {
        host = "" if app else either(header(headers, "host"), "localhost");
        base: any = new(globalThis.URL, app).origin if app else f"{scheme}://{host}";
        origin = new(globalThis.URL, base).origin;
    } except Exception {
        return False;
    }
    names = ["origin", "sec-fetch-site", "authorization"];
    sent = new(globalThis.Headers, [[n, header(headers, n)] for n in names if header(headers, n)]);
    request = new(globalThis.Request, f"{base}/api/realtime", record({"headers": sent}));
    return hasValidSessionMutationOrigin(request, origin);
}
