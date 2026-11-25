"""What the sign-in QR code encodes. The Mailflare mobile app scans it to fill in its sign-in form:
`mailflare://signin?server=…&email=…&key=…`."""
def buildSignInQrPayload(opts: any) -> str {
    (server, email, key) = (opts["server"], opts["email"], opts["key"]);
    pairs = [["server", server], *([["email", email]] if email else []), ["key", key]];
    return f"mailflare://signin?{new(globalThis.URLSearchParams, pairs).toString()}";
}
