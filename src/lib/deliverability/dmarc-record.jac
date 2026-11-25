# Edits the `rua` tag of a DMARC or TLS-RPT TXT record to add or remove our report address and
# nothing else: every other tag, its spacing and its order are kept byte for byte. Both record
# types share the tag syntax; only the version tag differs.
glob:priv RUA: any = rx(r"^(\s*rua\s*=\s*)([\s\S]*?)(\s*)$", "i");

"""`mailto:a@b!10m` -> `mailto:a@b`, compared case-insensitively."""
def:priv destination(uri: any) -> str {
    return rx_sub(uri.trim(), rx(r"![0-9]+[kmgt]?$", "i"), "").lower();
}

"""The record's `;` segments and the index of its `rua` tag, -1 without one."""
def:priv segmented(text: str) -> tuple[list[any], int] {
    (segments, tag) = (text.split(";"), rx(r"^\s*rua\s*=", "i"));
    return (segments, either(first([i for (i, s) in enumerate(segments) if tag.test(s)]), -1));
}

def hasRuaUri(text: str, address: str) -> bool {
    (segments, i) = segmented(text);
    value: str = RUA.exec(segments[i])[2] if i >= 0 else "";
    return f"mailto:{address.lower()}" in [destination(uri) for uri in value.split(",")];
}

def:priv edit(text: str, address: str, version: str, label: str, add: bool) -> str {
    kind = rx(f"^\\s*v={version}\\s*(?:;|$)", "i").test(text);
    if not kind or not rx(r'^[^\s,;@!<>"]+@[a-z0-9.-]+$', "i").test(address) {
        raise new(globalThis.Error, "Invalid report address" if kind else f"Not a {label} record");
    }
    if hasRuaUri(text, address) == add {
        return text;
    }
    (uri, (segments, i), space) = (f"mailto:{address}", segmented(text), rx(r"\s+$"));
    if i < 0 {
        base: str = rx_sub(text, space, "");
        return f"{base}{' ' if base.endswith(';') else '; '}rua={uri}";
    }
    found = RUA.exec(segments[i]);
    (key, value, trailing) = (found[1], found[2], found[3]);
    kept = [u.trim() for u in value.split(",") if u.trim() and destination(u) != uri.lower()];
    kept = ([rx_sub(value, space, "")] if value.trim() else []) + [uri] if add else kept;
    if kept {
        segments[i] = key + ",".join(kept) + trailing;
    } else {
        segments.pop(i);
    }
    return ";".join(segments);
}

def withRuaUri(text: str, address: str) -> str {
    return edit(text, address, "DMARC1", "DMARC", True);
}

def withoutRuaUri(text: str, address: str) -> str {
    return edit(text, address, "DMARC1", "DMARC", False);
}

def withTlsRuaUri(text: str, address: str) -> str {
    return edit(text, address, "TLSRPTv1", "TLS-RPT", True);
}

def withoutTlsRuaUri(text: str, address: str) -> str {
    return edit(text, address, "TLSRPTv1", "TLS-RPT", False);
}

"""`hasRuaUri` only reads the `rua` tag, so it serves both record types."""
def hasTlsRuaUri(text: str, address: str) -> bool {
    return hasRuaUri(text, address);
}
