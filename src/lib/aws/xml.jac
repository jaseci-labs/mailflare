"""Small flat AWS XML read without a parser; `xmlBlocks` keeps inner XML raw (still escaped)."""
# JavaScript's own string methods, called directly: Jac's dispatch on every match costs more than the match.
glob:priv LT: any = rx("&lt;", "g"),
          GT: any = rx("&gt;", "g"),
          QUOT: any = rx("&quot;", "g"),
          APOS: any = rx("&apos;", "g"),
          AMP: any = rx("&amp;", "g");

def:priv unescape(v: any) -> str {
    s: any = globalThis.String.prototype.trim.call(v);
    i: int = globalThis.String.prototype.indexOf.call(s, "&");
    if i < 0 {
        return s;
    }
    s = globalThis.String.prototype.replace.call(s, LT, "<");
    s = globalThis.String.prototype.replace.call(s, GT, ">");
    s = globalThis.String.prototype.replace.call(s, QUOT, '"');
    s = globalThis.String.prototype.replace.call(s, APOS, "'");
    return globalThis.String.prototype.replace.call(s, AMP, "&");
}

def:priv pattern(name: str, flags: str) -> any {
    return rx(f"<{name}(?:\\s[^>]*)?>([\\s\\S]*?)</{name}>", flags);
}

def xmlTag(xml: any, name: str) -> any {
    m: any = globalThis.RegExp.prototype.exec.call(pattern(name, ""), xml);
    return NULL if m is NULL else unescape(globalThis.Reflect.get(m, 1));
}

def xmlTags(xml: any, name: str) -> list[str] {
    out: list[str] = [];
    for m in globalThis.String.prototype.matchAll.call(xml, pattern(name, "g")) {
        out.append(unescape(globalThis.Reflect.get(m, 1)));
    }
    return out;
}

def xmlBlocks(xml: any, name: str) -> list[str] {
    out: list[any] = [];
    for m in globalThis.String.prototype.matchAll.call(xml, pattern(name, "g")) {
        out.append(globalThis.Reflect.get(m, 1));
    }
    return out;
}
