"""AWS Query and S3 responses are small flat XML documents; these helpers read them without a parser."""

def:priv element(name: str, flags: str = "") -> any {
    return rx("<" + name + r"(?:\s[^>]*)?>([\s\S]*?)</" + name + ">", flags);
}

def:priv unescape_xml(value: any) -> str {
    text: str = value.trim();
    for (entity, char) in [
        ("&lt;", "<"),
        ("&gt;", ">"),
        ("&quot;", '"'),
        ("&apos;", "'"),
        ("&amp;", "&"),
    ] {
        text = text.replace(entity, char);
    }
    return text;
}

def xmlTag(xml: any, name: str) -> any {
    found = element(name).exec(xml);
    return unescape_xml(found[1]) if found else NULL;
}

def xmlTags(xml: any, name: str) -> list[str] {
    return [unescape_xml(found[1]) for found in xml.matchAll(element(name, "g"))];
}

"""Raw (still escaped) inner XML of each repeated element, for reading nested fields."""
def xmlBlocks(xml: any, name: str) -> list[str] {
    return [found[1] for found in xml.matchAll(element(name, "g"))];
}
