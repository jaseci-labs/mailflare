glob:priv HEADER: any = rx(r'^(?:"((?:[^"\\]|\\.)*)"|([^<"]+))?\s*<([^>]+)>$'),
          UNESCAPE: any = rx(r"\\(.)", "g");

def formatEmailAddress(address: str, name: str | None = None) -> str {
    shown = (name or "").strip();
    if not shown {
        return address.strip();
    }
    quoted = shown.replace("\\", "\\\\").replace('"', '\\"');
    return f'"{quoted}" <{address.strip()}>';
}

"""`"Maya \"MJ\" Chen" <maya@example.com>` into its name and address; the name is optional."""
def parseEmailAddressParts(value: str) -> any {
    trimmed = value.strip();
    found = HEADER.exec(trimmed);
    if not found {
        return record({"name": NULL, "address": trimmed});
    }
    name: str = rx_sub(found[1], UNESCAPE, "$1") if found[1] else (found[2] or "");
    return record({"name": name.strip() or NULL, "address": found[3].strip()});
}

def getEmailAddress(value: str) -> str {
    return parseEmailAddressParts(value)["address"];
}

def normalizeEmailAddress(value: str) -> str {
    return getEmailAddress(value).strip().lower();
}

def getEmailDisplayName(value: str) -> str {
    parts = parseEmailAddressParts(value);
    if parts["name"] {
        return parts["name"];
    }
    parsed = parseAddress(parts["address"]);
    return (parsed.local if parsed else "") or parts["address"];
}

def:priv postal_mailboxes(address: any) -> list[any] {
    if not address {
        return [];
    }
    return [address]
        if getattr(address, "address", None)
        else list(getattr(address, "group", None) or []);
}

def formatPostalAddress(address: any, fallback: str | None) -> str | None {
    boxes = postal_mailboxes(address);
    if not boxes or not getattr(boxes[0], "address", None) {
        return fallback;
    }
    return formatEmailAddress(boxes[0].address, getattr(boxes[0], "name", None));
}

"""Every mailbox of a header address list, comma-joined, so reply-all sees the full To/Cc line."""
def formatPostalAddressList(addresses: any, fallback: str | None) -> str | None {
    boxes = [
        box
        for address in addresses or []
        for box in postal_mailboxes(address)
        if getattr(box, "address", None)
    ];
    if not boxes {
        return fallback;
    }
    return ", ".join([
        formatEmailAddress(box.address, getattr(box, "name", None))
        for box in boxes
    ]);
}

"""Split a header value on `,` and `;`, leaving those inside a quoted name or `<...>` alone."""
def splitEmailAddressList(value: str | None = None) -> list[str] {
    result: list[str] = [];
    current = "";
    (quoted, angled, escaped) = (False, False, False);
    for ch in value or "" {
        if escaped {
            escaped = False;
        } elif ch == "\\" and quoted {
            escaped = True;
        } elif ch == '"' and not angled {
            quoted = not quoted;
        } elif ch in "<>" and not quoted {
            angled = ch == "<";
        } elif ch in ",;" and not quoted and not angled {
            if current.strip() {
                result.append(current.strip());
            }
            current = "";
            continue;
        }
        current += ch;
    }
    if current.strip() {
        result.append(current.strip());
    }
    return result;
}

"""Bare, lower-cased addresses of a header list, deduplicated in order."""
def getEmailAddressList(value: str | None = None) -> list[str] {
    result: list[str] = [];
    for item in splitEmailAddressList(value) {
        address = normalizeEmailAddress(item);
        if address and address not in result {
            result.append(address);
        }
    }
    return result;
}

"""True when `address` is exactly one of the addresses in `value`, case-insensitively."""
def addressListIncludes(value: str | None, address: str) -> bool {
    wanted = normalizeEmailAddress(address);
    return bool(wanted) and wanted in getEmailAddressList(value);
}

def joinEmailAddressList(values: list[str]) -> str {
    return ", ".join([v.strip() for v in values if v.strip()]);
}

"""The first address of a list, for places that show a single party."""
def getFirstEmailAddressEntry(value: str | None = None) -> str {
    entries = splitEmailAddressList(value);
    return entries[0] if entries else (value or "").strip();
}
