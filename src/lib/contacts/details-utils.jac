glob MAX_NAME: int = 100;

glob MAX_EMAIL: int = 254;

glob:priv MAX_EMAILS: int = 20,
          MAX_PHONES: int = 20,
          MAX_ADDRESSES: int = 10,
          MAX_TYPE: int = 32,
          MAX_PHONE: int = 64,
          MAX_ADDRESS: int = 500,
          MAX_ORGANIZATION: int = 200,
          MAX_NOTE: int = 4000,
          CONTROLS: any = rx(r"[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]", "g"),
          LINE_CONTROLS: any = rx(r"[\u0000-\u001f\u007f]+", "g"),
          # A bare address: no display name, no list separators, and a dot in the domain.
          BARE_ADDRESS: any = rx(r'^[^@\s<>",;]{1,64}@[^@\s<>",;]+\.[^@\s<>",;]+$');

"""`rx_sub` whose result keeps JavaScript's string methods."""
def:priv sub(s: any, regex: any, to: str) -> any {
    return rx_sub(s, regex, to);
}

def:priv is_pair(value: any) -> bool {
    return not nil(value)
        and globalThis.Object(value) is value
        and not globalThis.Array.isArray(value)
        and not globalThis.Function.prototype.isPrototypeOf(value);
}

"""`o.k` of a record that may be absent."""
def:priv field(o: any, k: str) -> any {
    return NULL if nil(o) else at(o, k);
}

"""One line: controls (and so line breaks) become a space, the ends are trimmed and the length is capped."""
def cleanLine(value: any, limit: int) -> any {
    if not isinstance(value, str) {
        return "";
    }
    return sub(
        sub(value.slice(0, limit * 2), LINE_CONTROLS, " "), rx(" {2,}", "g"), " "
    ).trim().slice(0, limit).trim();
}

"""Text that may span lines: controls other than tab and line breaks are removed, CRLF becomes LF."""
def cleanText(value: any, limit: int) -> any {
    if not isinstance(value, str) {
        return "";
    }
    return sub(sub(value.slice(0, limit * 2), rx(r"\r\n?", "g"), "\n"), CONTROLS, "").trim().slice(
        0, limit
    ).trim();
}

"""The valid addresses of a card as stored: lower-cased, de-duplicated, order kept, at most 20."""
def importedContactEmails(raw: any) -> list[str] {
    emails: list[str] = [];
    for value in raw {
        if not isinstance(value, str) or value.length > MAX_EMAIL * 2 {
            continue;
        }
        address = cleanLine(value, MAX_EMAIL).toLowerCase();
        if address.length > MAX_EMAIL or not BARE_ADDRESS.test(address) or address in emails {
            continue;
        }
        emails.append(address);
        if len(emails) >= MAX_EMAILS {
            break;
        }
    }
    return emails;
}

"""`YYYY-MM-DD`, or `--MM-DD` without a year; undefined for anything else (including impossible dates)."""
def normalizeBirthday(value: any = None) -> any {
    if not isinstance(value, str) {
        return None;
    }
    found = rx(r"^(\d{4}|--)-?(\d{2})-?(\d{2})").exec(value.trim().slice(0, 20));
    if not found {
        return None;
    }
    (month, day) = (globalThis.Number(found[2]), globalThis.Number(found[3]));
    if month < 1 or month > 12 or day < 1 or day > 31 {
        return None;
    }
    return f"--{found[2]}-{found[3]}" if found[1] == "--" else f"{found[1]}-{found[2]}-{found[3]}";
}

"""Labelled values of a card (phones, postal addresses): cleaned, counted once per `key_of` its value, capped."""
def:priv labelled(items: any, name: str, width: int, cap: int, key_of: any) -> list[any] {
    seen: list[str] = [];
    out: list[any] = [];
    for item in (items[:cap * 4] if globalThis.Array.isArray(items) else []) {
        if not is_pair(item) {
            continue;
        }
        value = cleanLine(item[name], width);
        key = key_of(value);
        if not key or key in seen {
            continue;
        }
        seen.append(key);
        out.append({"type": cleanLine(item["type"], MAX_TYPE), name: value});
        if len(out) >= cap {
            break;
        }
    }
    return out;
}

"""
The only way details enter or leave the table: unknown keys are dropped, text is cleaned, lengths and counts are
capped and empty values are removed. Applied to imported data before it is written and to stored JSON before it is
served.

A future CSV export of contacts must neutralize cells that start with = + - or @ (see csvSafeCell).
"""
def normalizeContactDetails(input: any = None) -> dict[str, any] {
    if not is_pair(input) {
        return {};
    }
    emails = input["emails"];
    found: list[tuple[str, any]] = [
        (
            "emails",
            importedContactEmails(emails[:MAX_EMAILS * 4])
                if globalThis.Array.isArray(emails)
                else [],
        ),
        (
            "phones",
            labelled(
                input["phones"],
                "value",
                MAX_PHONE,
                MAX_PHONES,
                lambda (v: any) -> str { sub(v, rx(r"[\s().-]", "g"), "") },
            ),
        ),
        (
            "addresses",
            labelled(
                input["addresses"],
                "formatted",
                MAX_ADDRESS,
                MAX_ADDRESSES,
                lambda (v: any) -> str { v.toLowerCase() },
            ),
        ),
        ("organization", cleanLine(input["organization"], MAX_ORGANIZATION)),
        ("title", cleanLine(input["title"], MAX_ORGANIZATION)),
        ("birthday", normalizeBirthday(input["birthday"])),
        ("note", cleanText(input["note"], MAX_NOTE)),
    ];
    return {k: v for (k, v) in found if v};
}

"""The details of one card: its addresses are kept apart, as the contact's own rows."""
def withoutEmails(details: any) -> dict[str, any] {
    return {k: v for (k, v) in entries(details) if k != "emails"};
}

"""Stored details JSON, normalized again; unreadable JSON is "no details"."""
def parseStoredDetails(json: any = None) -> dict[str, any] {
    if not json or json.length > 64 * 1024 {
        return {};
    }
    try {
        return normalizeContactDetails(globalThis.JSON.parse(json));
    } except Exception {
        return {};
    }
}

"""
What the import writes to an existing (or new) contact's name and source. A name you set yourself (source `manual`) is
kept, and a manual contact stays manual. Any other name is replaced by the imported one and the contact becomes
`import`, so a later import may update that name again but never one you edited (editing makes it `manual`); an
`outbound` contact keeps that source (the name rules still apply) so an import never downgrades it. Without an
imported name the name stays, but an inbound contact on an imported card still becomes `import`.
`import` is treated like `manual` everywhere a contact counts as known or its name is shown (spam score, agent send
review, display name). `blocked` and `remoteContentAllowed` are never part of this decision.
"""
def mergeImportedContact(existing: any, importedName: any = None) -> dict[str, any] {
    name = cleanLine(importedName, MAX_NAME) or NULL;
    # The stored name is passed on as it is, null included.
    kept = NULL if nil(existing) else existing["displayName"];
    source = field(existing, "source");
    if source == "manual" {
        return {
            "displayName": kept if kept and kept.trim() else either(name, kept),
            "source": "manual",
        };
    }
    return {
        "displayName": either(either(name, kept), NULL),
        "source": "outbound" if source == "outbound" else "import",
    };
}

"""
The stored details with one more card's details folded in, for a re-import: addresses, phones and postal addresses
are united (same normalized value counts once, the stored label wins); organization, title, birthday and note come
from the card when it has them and stay as stored when it lacks them.
"""
def mergeContactDetails(existing: any, incoming: any) -> dict[str, any] {
    united: dict[str, any] = {
        k: list(either(field(existing, k), [])) + list(either(field(incoming, k), []))
        for k in ["emails", "phones", "addresses"]
    };
    for k in ["organization", "title", "birthday", "note"] {
        united[k] = either(field(incoming, k), field(existing, k));
    }
    return normalizeContactDetails(record(united));
}

"""A stored birthday for display in `locale`: "May 1, 1980", or "May 1" when the year is unknown."""
def formatBirthday(value: str, locale: any = None) -> str {
    found = rx(r"^(?:(\d{4})-|--)(\d{2})-(\d{2})$").exec(value);
    if not found {
        return value;
    }
    date = new(globalThis.Date, 0);
    date.setUTCFullYear(
        globalThis.Number(found[1]) if found[1] else 2000,
        globalThis.Number(found[2]) - 1,
        globalThis.Number(found[3]),
    );
    options = {"timeZone": "UTC", "month": "long", "day": "numeric"};
    if found[1] {
        options["year"] = "numeric";
    }
    try {
        return new(globalThis.Intl.DateTimeFormat, locale, record(options)).format(date);
    } except Exception {
        return value;
    }
}

"""A CSV cell that spreadsheet software will not run as a formula: a leading = + - or @ gets a quote in front."""
def csvSafeCell(value: str) -> str {
    return f"'{value}" if rx(r"^[=+\-@\t\r]").test(value) else value;
}
