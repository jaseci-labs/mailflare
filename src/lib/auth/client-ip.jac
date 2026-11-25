def:priv header_value(request: any, name: str) -> any {
    value: any = request.headers.get(name);
    return (value.trim() if value else None) or NULL;
}

"""The real client IP for rate limiting and audit metadata. Forwarded headers count only when someone
trustworthy set them: the self-host server resolves the IP at the socket (or the proxy hop it appended
under TRUST_PROXY), stamps it into x-mailflare-client-ip and strips every client-supplied forwarding
header; on Workers cf-connecting-ip is platform-set. A bare x-forwarded-for is the last resort for
other runtimes: its rightmost hop is the least attacker-controlled entry."""
def getClientIp(request: any) -> any {
    # cf-connecting-ip first, so a client-injected x-mailflare-client-ip cannot win on Workers; the
    # self-host server deletes cf-connecting-ip, so its stamped value is used there.
    fwd: any = header_value(request, "x-forwarded-for");
    last: any = fwd.split(",")[-1] if fwd else None;
    return header_value(request, "cf-connecting-ip")
        or header_value(request, "x-mailflare-client-ip")
        or (last.trim() if last else None)
        or NULL;
}
