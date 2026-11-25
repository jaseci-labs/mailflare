# JavaScript's own string and array methods are called directly: Jac's dispatch on every value
# costs more than the work.
glob:priv UNCARRIED: any = rx(r"[\u0000-\u0008\u000b\u000c\u000e-\u001f￾￿]", "g"),
          MARKUP: any = rx(r"""[&<>"']"""),
          AMP: any = rx("&", "g"),
          LT: any = rx("<", "g"),
          GT: any = rx(">", "g"),
          QUOT: any = rx('"', "g"),
          APOS: any = rx("'", "g"),
          ST: any = record({"200": "OK", "403": "Forbidden", "404": "Not Found", "507": "Insufficient Storage"});

"""Escape text or an attribute value. Characters XML 1.0 cannot carry are dropped."""
def escapeXml(value: str) -> str {
    s: any = globalThis.String.prototype.replace.call(value, UNCARRIED, "");
    if not globalThis.RegExp.prototype.test.call(MARKUP, s) {
        return s;
    }
    s = globalThis.String.prototype.replace.call(s, AMP, "&amp;");
    s = globalThis.String.prototype.replace.call(s, LT, "&lt;");
    s = globalThis.String.prototype.replace.call(s, GT, "&gt;");
    s = globalThis.String.prototype.replace.call(s, QUOT, "&quot;");
    return globalThis.String.prototype.replace.call(s, APOS, "&apos;");
}

# Props are already-serialised property elements; callers escape what they put inside.
def:priv response(r: any) -> str {
    stats: str = "";
    for s in globalThis.Reflect.get(r, "propstats") {
        st: any = globalThis.Reflect.get(s, "status");
        props: str = globalThis.Array.prototype.join.call(globalThis.Reflect.get(s, "props"), "");
        code: str = globalThis.String(st);
        text: str = globalThis.String(either(globalThis.Reflect.get(ST, st), ""));
        stats = stats + "<D:propstat><D:prop>" + props + "</D:prop><D:status>HTTP/1.1 " + code + " " + text + "</D:status></D:propstat>";
    }
    href: str = escapeXml(globalThis.Reflect.get(r, "href"));
    return "<D:response><D:href>" + href + "</D:href>" + stats + "</D:response>";
}

# The root declares D = DAV:, C = CalDAV, CR = CardDAV, CS = calendarserver.org.
def multistatus(responses: any) -> str {
    ns = 'xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav" xmlns:CR="urn:ietf:params:xml:ns:carddav" xmlns:CS="http://calendarserver.org/ns/"';
    body: str = "";
    for r in responses {
        body = body + response(r);
    }
    return f'<?xml version="1.0" encoding="utf-8"?>\n<D:multistatus {ns}>{body}</D:multistatus>';
}

# Shapes a TypeScript caller names: a propstat is {status, props}, a response {href, propstats}.
type DavPropstat = any;

type DavResponse = any;
