"""
Edits the `rua` tag of a DMARC or TLS-RPT TXT record to add or remove our report address and nothing else: every
other tag, its spacing and its order are kept byte for byte. Both record types share the tag syntax; only the
version tag differs.
"""

glob:priv DMARC: tuple[str, str] = ("DMARC1", "DMARC"),
          TLS_RPT: tuple[str, str] = ("TLSRPTv1", "TLS-RPT"),
          ADDRESS: any = rx(r'^[^\s,;@!<>"]+@[a-z0-9.-]+$', "i"),
          SIZE_LIMIT: any = rx(r"![0-9]+[kmgt]?$", "i"),
          RUA_TAG: any = rx(r"^\s*rua\s*=", "i"),
          RUA: any = rx(r"^(\s*rua\s*=\s*)([\s\S]*?)(\s*)$", "i"),
          TRAILING_SPACE: any = rx(r"\s+$");

def:priv check(text: str, address: str, kind: tuple[str, str]) {
    (version, label) = kind;
    if not rx(f"^\\s*v={version}\\s*(?:;|$)", "i").test(text) {
        raise new(globalThis.Error, f"Not a {label} record");
    }
    if not ADDRESS.test(address) {
        raise new(globalThis.Error, "Invalid report address");
    }
}

"""`mailto:a@b!10m` -> `mailto:a@b`, compared case-insensitively."""
def:priv destination(uri: any) -> str {
    return rx_sub(uri.trim(), SIZE_LIMIT, "").lower();
}

"""The record's `;` segments and the index of its `rua` tag, -1 without one."""
def:priv segmented(text: str) -> tuple[list[any], int] {
    segments = text.split(";");
    for (i, segment) in enumerate(segments) {
        if RUA_TAG.test(segment) {
            return (segments, i);
        }
    }
    return (segments, -1);
}

def hasRuaUri(text: str, address: str) -> bool {
    (segments, index) = segmented(text);
    if index < 0 {
        return False;
    }
    found = RUA.exec(segments[index]);
    value: str = either(found[2], "") if found else "";
    return f"mailto:{address.lower()}" in [destination(uri) for uri in value.split(",")];
}

def:priv add_uri(text: str, address: str, kind: tuple[str, str]) -> str {
    check(text, address, kind);
    if hasRuaUri(text, address) {
        return text;
    }
    uri = f"mailto:{address}";
    (segments, index) = segmented(text);
    if index < 0 {
        base: str = rx_sub(text, TRAILING_SPACE, "");
        return f"{base}{' ' if base.endswith(';') else '; '}rua={uri}";
    }
    found = RUA.exec(segments[index]);
    (key, value, trailing) = (found[1], found[2], found[3]);
    joined = f"{rx_sub(value, TRAILING_SPACE, '')},{uri}" if value.trim() else uri;
    segments[index] = f"{key}{joined}{trailing}";
    return ";".join(segments);
}

def:priv remove_uri(text: str, address: str, kind: tuple[str, str]) -> str {
    check(text, address, kind);
    if not hasRuaUri(text, address) {
        return text;
    }
    (segments, index) = segmented(text);
    found = RUA.exec(segments[index]);
    value: str = found[2];
    uris: list[any] = value.split(",");
    kept = [
        uri.trim()
        for uri in uris
        if uri.trim() and destination(uri) != f"mailto:{address.lower()}"
    ];
    if kept {
        segments[index] = f"{found[1]}{','.join(kept)}{found[3]}";
    } else {
        segments.pop(index);
    }
    return ";".join(segments);
}

def withRuaUri(text: str, address: str) -> str {
    return add_uri(text, address, DMARC);
}

def withoutRuaUri(text: str, address: str) -> str {
    return remove_uri(text, address, DMARC);
}

def withTlsRuaUri(text: str, address: str) -> str {
    return add_uri(text, address, TLS_RPT);
}

def withoutTlsRuaUri(text: str, address: str) -> str {
    return remove_uri(text, address, TLS_RPT);
}

"""`hasRuaUri` only reads the `rua` tag, so it serves both record types."""
def hasTlsRuaUri(text: str, address: str) -> bool {
    return hasRuaUri(text, address);
}
