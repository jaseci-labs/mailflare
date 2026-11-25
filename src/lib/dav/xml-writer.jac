glob:priv UNCARRIED: any = rx(r"[\u0000-\u0008\u000b\u000c\u000e-\u001f￾￿]", "g"),
          MARKUP: any = rx(r"""[&<>"']""", "g"),
          ENTITIES: dict[str, str] = {
              "&": "&amp;",
              "<": "&lt;",
              ">": "&gt;",
              '"': "&quot;",
              "'": "&apos;",
          },
          STATUS_TEXT: dict[int, str] = {
              200: "OK",
              403: "Forbidden",
              404: "Not Found",
              507: "Insufficient Storage",
          },
          # The prefixes every response declares once on its root: D = DAV:, C = CalDAV, CR = CardDAV, CS = calendarserver.org.
          ROOT_NAMESPACES: str = 'xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:CR="urn:ietf:params:xml:ns:carddav" xmlns:CS="http://calendarserver.org/ns/"';

"""Escape text or an attribute value. Characters XML 1.0 cannot carry are dropped."""
def escapeXml(value: str) -> str {
    return rx_sub(rx_sub(value, UNCARRIED, ""), MARKUP, lambda (ch: str) -> str { ENTITIES[ch] });
}

def:priv propstat(stat: any) -> str {
    status: any = stat["status"];
    return f"<D:propstat><D:prop>{''.join(stat['props'])}</D:prop><D:status>HTTP/1.1 {status} {STATUS_TEXT.get(status, '')}</D:status></D:propstat>";
}

"""Each propstat's props are already-serialised property elements; callers escape what they put inside."""
def multistatus(responses: any) -> str {
    body = "".join([
        f"<D:response><D:href>{escapeXml(r['href'])}</D:href>{''.join([propstat(s) for s in r['propstats']])}</D:response>"
        for r in responses
    ]);
    return f'<?xml version="1.0" encoding="utf-8"?>\n<D:multistatus {ROOT_NAMESPACES}>{body}</D:multistatus>';
}

# Shapes a TypeScript caller names: a propstat is {status, props}, a response {href, propstats}.
type DavPropstat = any;

type DavResponse = any;
