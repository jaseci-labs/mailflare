"""Small flat AWS XML read without a parser; `xmlBlocks` keeps inner XML raw (still escaped)."""
glob:priv C: any = record({"&lt;": "<", "&gt;": ">", "&quot;": '"', "&apos;": "'", "&amp;": "&"});

def:priv unescape(v: any) -> str {
    return rx_sub(v.trim(), rx("&(lt|gt|quot|apos|amp);", "g"), lambda (e: any) -> any { C[e] });
}

def xmlTag(xml: any, name: str) -> any {
    return either(first(xmlTags(globalThis.String(xml), name)), NULL);
}

def xmlTags(xml: any, name: str) -> list[str] {
    return [unescape(b) for b in xmlBlocks(xml, name)];
}

def xmlBlocks(xml: any, name: str) -> list[str] {
    return [m[1] for m in xml.matchAll(rx(f"<{name}(?:\\s[^>]*)?>([\\s\\S]*?)</{name}>", "g"))];
}
