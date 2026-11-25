glob:priv UNCARRIED: any = rx(r"[\u0000-\u0008\u000b\u000c\u000e-\u001f￾￿]", "g"),
          MARKUP: any = rx(r"""[&<>"']""", "g"),
          ENTITIES: any = {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;"},
          ST: any = {200: "OK", 403: "Forbidden", 404: "Not Found", 507: "Insufficient Storage"};

"""Escape text or an attribute value. Characters XML 1.0 cannot carry are dropped."""
def escapeXml(value: str) -> str {
    return rx_sub(rx_sub(value, UNCARRIED, ""), MARKUP, lambda (ch: str) -> str { ENTITIES[ch] });
}

# Props are already-serialised property elements; callers escape what they put inside.
def:priv response(r: any) -> str {
    stats = "";
    for s in r["propstats"] {
        (st, props) = (s["status"], "".join(s["props"]));
        stats += f"<D:propstat><D:prop>{props}</D:prop><D:status>HTTP/1.1 {st} {ST.get(st, '')}</D:status></D:propstat>";
    }
    return f"<D:response><D:href>{escapeXml(r['href'])}</D:href>{stats}</D:response>";
}

# The root declares D = DAV:, C = CalDAV, CR = CardDAV, CS = calendarserver.org.
def multistatus(responses: any) -> str {
    ns = 'xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:CR="urn:ietf:params:xml:ns:carddav" xmlns:CS="http://calendarserver.org/ns/"';
    body = "".join([response(r) for r in responses]);
    return f'<?xml version="1.0" encoding="utf-8"?>\n<D:multistatus {ns}>{body}</D:multistatus>';
}

# Shapes a TypeScript caller names: a propstat is {status, props}, a response {href, propstats}.
type DavPropstat = any;

type DavResponse = any;
