glob MAX_NAME: int = 100,
     MAX_EMAIL: int = 254;

glob:priv CONTROLS: any = rx(r"[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]", "g"),
          LINE_CONTROLS: any = rx(r"[\u0000-\u001f\u007f]+", "g"),
          BIRTHDAY: any = rx(r"^(\d{4}|--)-?(\d{2})-?(\d{2})"),
          # A bare address: no display name, no list separators, and a dot in the domain.
          BARE_ADDRESS: any = rx(r'^[^@\s<>",;]{1,64}@[^@\s<>",;]+\.[^@\s<>",;]+$'),
          isArray: any = globalThis.Array.isArray,
          is_pair: any = lambda (v: any) -> bool { is_object(v) and not isArray(v) },
          field: any = lambda (o: any, k: str) -> any { NULL if nil(o) else at(o, k) },
          phone_key: any = lambda (s: any) -> any { sub(s, rx(r"[\s().-]", "g"), "") },
          lower: any = lambda (s: any) -> any { s.toLowerCase() };

"""One line: controls (and so line breaks) become a space, the ends are trimmed and the length is capped."""
def cleanLine(value: any, limit: int) -> any {
    if not isinstance(value, str) {
        return "";
    }
    s = sub(sub(value.slice(0, limit * 2), LINE_CONTROLS, " "), rx(" {2,}", "g"), " ");
    return s.trim().slice(0, limit).trim();
}

"""Text that may span lines: controls other than tab and line breaks are removed, CRLF becomes LF."""
def cleanText(value: any, limit: int) -> any {
    if not isinstance(value, str) {
        return "";
    }
    s = sub(sub(value.slice(0, limit * 2), rx(r"\r\n?", "g"), "\n"), CONTROLS, "");
    return s.trim().slice(0, limit).trim();
}

"""The valid addresses of a card as stored: lower-cased, de-duplicated, order kept, at most 20."""
def importedContactEmails(raw: any) -> list[str] {
    emails = [];
    for value in raw {
        fits = isinstance(value, str) and value.length <= MAX_EMAIL * 2;
        address = cleanLine(value, MAX_EMAIL).toLowerCase() if fits else "";
        if address.length <= MAX_EMAIL and BARE_ADDRESS.test(address) and address not in emails {
            emails.append(address);
            if len(emails) >= 20 {
                break;
            }
        }
    }
    return emails;
}

"""`YYYY-MM-DD`, or `--MM-DD` without a year; undefined for anything else (including impossible dates)."""
def normalizeBirthday(value: any = None) -> any {
    m = BIRTHDAY.exec(value.trim().slice(0, 20)) if isinstance(value, str) else NULL;
    if not m or not 1 <= globalThis.Number(m[2]) <= 12 or not 1 <= globalThis.Number(m[3]) <= 31 {
        return None;
    }
    return f"--{m[2]}-{m[3]}" if m[1] == "--" else f"{m[1]}-{m[2]}-{m[3]}";
}

# Labelled values (phones, postal addresses): cleaned, counted once per `key_of` their value, capped.
def:priv labelled(items: any, name: str, width: int, cap: int, key_of: any) -> list[any] {
    (seen, out) = ([], []);
    for item in (items.slice(0, cap * 4) if isArray(items) else []) {
        value = cleanLine(item[name], width) if is_pair(item) else "";
        key = key_of(value);
        if key and key not in seen {
            seen.append(key);
            out.append({"type": cleanLine(item["type"], 32), name: value});
            if len(out) >= cap {
                break;
            }
        }
    }
    return out;
}

# The only way details enter or leave the table: unknown keys dropped, text cleaned, lengths and counts
# capped, empty values removed. A future CSV export must neutralize formula cells (see csvSafeCell).
def normalizeContactDetails(input: any = None) -> dict[str, any] {
    if not is_pair(input) {
        return {};
    }
    (v, mails) = (input, input["emails"]);
    line = lambda (k: str) -> any { cleanLine(input[k], 200) };
    e = importedContactEmails(mails.slice(0, 80)) if isArray(mails) else [];
    p = labelled(v["phones"], "value", 64, 20, phone_key);
    a = labelled(v["addresses"], "formatted", 500, 10, lower);
    found = {"emails": e, "phones": p, "addresses": a, "organization": line("organization")};
    (found["title"], found["birthday"]) = (line("title"), normalizeBirthday(v["birthday"]));
    found["note"] = cleanText(v["note"], 4000);
    return {k: x for (k, x) in found.items() if x};
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

# An import keeps a `manual` name (and source); any other name is replaced and the source becomes
# `import`, except that `outbound` stays. Without an imported name the stored one stays, null included.
def mergeImportedContact(existing: any, importedName: any = None) -> dict[str, any] {
    (name, source) = (cleanLine(importedName, MAX_NAME) or NULL, field(existing, "source"));
    kept = NULL if nil(existing) else existing["displayName"];
    manual = source == "manual";
    shown = kept if manual and kept and kept.trim() else either(name, kept);
    shown = shown if manual else either(shown, NULL);
    kind = source if source in ["manual", "outbound"] else "import";
    return {"displayName": shown, "source": kind};
}

# Re-import: emails, phones and addresses are united (the stored label wins); the other fields come
# from the card when it has them.
def mergeContactDetails(old: any, cur: any) -> dict[str, any] {
    ls = lambda (o: any, k: str) -> any { list(either(field(o, k), [])) };
    united = {k: ls(old, k) + ls(cur, k) for k in ["emails", "phones", "addresses"]};
    for k in ["organization", "title", "birthday", "note"] {
        united[k] = either(field(cur, k), field(old, k));
    }
    return normalizeContactDetails(record(united));
}

"""A stored birthday for display in `locale`: "May 1, 1980", or "May 1" when the year is unknown."""
def formatBirthday(value: str, locale: any = None) -> str {
    m = rx(r"^(?:(\d{4})-|--)(\d{2})-(\d{2})$").exec(value);
    if not m {
        return value;
    }
    (date, n) = (new(globalThis.Date, 0), [globalThis.Number(x) for x in m]);
    date.setUTCFullYear(n[1] if m[1] else 2000, n[2] - 1, n[3]);
    year = {"year": "numeric"} if m[1] else {};
    options = merged({"timeZone": "UTC", "month": "long", "day": "numeric"}, year);
    try {
        return new(globalThis.Intl.DateTimeFormat, locale, options).format(date);
    } except Exception {
        return value;
    }
}

"""A CSV cell that spreadsheet software will not run as a formula: a leading = + - or @ gets a quote in front."""
def csvSafeCell(value: str) -> str {
    return f"'{value}" if rx(r"^[=+\-@\t\r]").test(value) else value;
}
