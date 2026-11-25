def:priv header_value(request: any, name: str) -> any {
    value: any = request.headers.get(name);
    return (value.trim() if value else None) or NULL;
}

"""Resolve the real client IP for rate limiting and audit metadata.

Forwarded headers are only meaningful when someone trustworthy set them: the self-host server
resolves the IP at the socket (or the proxy hop it appended under TRUST_PROXY), stamps it into
x-mailflare-client-ip, and strips every client-supplied forwarding header before app code runs.
On Workers, cf-connecting-ip is platform-set and cannot be forged. A bare x-forwarded-for is the
last resort for other runtimes: its rightmost hop is the least attacker-controlled entry."""
def getClientIp(request: any) -> any {
    # cf-connecting-ip first: checking it before x-mailflare-client-ip keeps a client-injected copy
    # of the private header from winning on Workers. The self-host server deletes cf-connecting-ip
    # outright, so the stamped value is used next.
    forwarded: any = header_value(request, "x-forwarded-for");
    last: any = forwarded.split(",")[-1] if forwarded else None;
    return header_value(request, "cf-connecting-ip")
        or header_value(request, "x-mailflare-client-ip")
        or (last.trim() if last else None)
        or NULL;
}
