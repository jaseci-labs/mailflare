glob MAX_NAME: int = 100,
     MAX_EMAIL: int = 254;

# Strings, regexes and objects go through JavaScript's own methods, called directly, and every regex
# is made once here: Jac's dispatch on untyped values costs more than the cleaning. The `g` regexes
# are only used by `replace`, which neither reads nor leaves `lastIndex`.
glob:priv CONTROLS: any = rx(r"[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]", "g"),
          LINE_CONTROLS: any = rx(r"[\u0000-\u001f\u007f]+", "g"),
          SPACE_RUNS: any = rx(" {2,}", "g"),
          CRLF: any = rx(r"\r\n?", "g"),
          PHONE_PUNCTUATION: any = rx(r"[\s().-]", "g"),
          BIRTHDAY: any = rx(r"^(\d{4}|--)-?(\d{2})-?(\d{2})"),
          STORED_BIRTHDAY: any = rx(r"^(?:(\d{4})-|--)(\d{2})-(\d{2})$"),
          CSV_FORMULA: any = rx(r"^[=+\-@\t\r]"),
          # A bare address: no display name, no list separators, and a dot in the domain.
          BARE_ADDRESS: any = rx(r'^[^@\s<>",;]{1,64}@[^@\s<>",;]+\.[^@\s<>",;]+$'),
          field: any = lambda (o: any, k: str) -> any { NULL if nil(o) else at(o, k) };

# JavaScript's `!!v && typeof v === "object" && !Array.isArray(v)`.
def:priv is_pair(v: any) -> bool {
    return is_object(v) and not globalThis.Array.isArray(v);
}

def:priv utf16_length(s: str) -> int {
    return globalThis.Reflect.get(globalThis.Object(s), "length");
}

def:priv trimmed_to(s: str, limit: int) -> str {
    t: str = globalThis.String.prototype.trim.call(s);
    return globalThis.String.prototype.trim.call(
        globalThis.String.prototype.slice.call(t, 0, limit)
    );
}

"""One line: controls (and so line breaks) become a space, the ends are trimmed and the length is capped."""
def cleanLine(value: any, limit: int) -> str {
    if not isinstance(value, str) {
        return "";
    }
    s: str = globalThis.String.prototype.slice.call(value, 0, limit * 2);
    s = globalThis.String.prototype.replace.call(s, LINE_CONTROLS, " ");
    s = globalThis.String.prototype.replace.call(s, SPACE_RUNS, " ");
    return trimmed_to(s, limit);
}

"""Text that may span lines: controls other than tab and line breaks are removed, CRLF becomes LF."""
def cleanText(value: any, limit: int) -> str {
    if not isinstance(value, str) {
        return "";
    }
    s: str = globalThis.String.prototype.slice.call(value, 0, limit * 2);
    s = globalThis.String.prototype.replace.call(s, CRLF, "\n");
    s = globalThis.String.prototype.replace.call(s, CONTROLS, "");
    return trimmed_to(s, limit);
}

# Adds `value` to `emails` when it is a bare address not yet there (lower-cased); False once 20 are kept.
def:priv add_email(emails: list[str], value: any) -> bool {
    if isinstance(value, str) and utf16_length(value) <= MAX_EMAIL * 2 {
        line: str = cleanLine(value, MAX_EMAIL);
        address: str = globalThis.String.prototype.toLowerCase.call(line);
        if utf16_length(address) <= MAX_EMAIL
            and globalThis.RegExp.prototype.test.call(BARE_ADDRESS, address)
            and address not in emails
        {
            emails.append(address);
            return len(emails) < 20;
        }
    }
    return True;
}

"""The valid addresses of a card as stored: lower-cased, de-duplicated, order kept, at most 20."""
def importedContactEmails(raw: any) -> list[str] {
    emails: list[str] = [];
    for value in raw {
        if not add_email(emails, value) {
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
    t: str = globalThis.String.prototype.trim.call(value);
    m: any = globalThis.RegExp.prototype.exec.call(
        BIRTHDAY, globalThis.String.prototype.slice.call(t, 0, 20)
    );
    if m is NULL {
        return None;
    }
    # Every group takes part in a match, so each is a string.
    y: str = m[1];
    mo: str = m[2];
    d: str = m[3];
    month: float = globalThis.Number(mo);
    day: float = globalThis.Number(d);
    if month < 1 or month > 12 or day < 1 or day > 31 {
        return None;
    }
    return "--" + mo + "-" + d if y == "--" else y + "-" + mo + "-" + d;
}

# Labelled values (phones, postal addresses) among the first `cap * 4` items: cleaned, counted once
# per key of their value (`phone`: without spaces and punctuation, else lower-cased), capped. Each is
# `{type, <name>: value}`. The array is read in place: a slice of it, or a typed view, is a copy.
def:priv labelled(items: any, name: str, width: int, cap: int, phone: bool) -> list[any] {
    out: list[any] = [];
    if not isinstance(items, list) {
        return out;
    }
    n: int = min(len(items), cap * 4);
    seen: list[str] = [];
    for i in range(n) {
        item: any = items[i];
        if is_pair(item) {
            value: str = cleanLine(globalThis.Reflect.get(item, name), width);
            key: str = globalThis.String.prototype.replace.call(value, PHONE_PUNCTUATION, "")
                if phone
                else globalThis.String.prototype.toLowerCase.call(value);
            # A phone counts when its key is not empty, an address when its value is not.
            counted: str = key if phone else value;
            if counted and key not in seen {
                seen.append(key);
                labelled_item: any = globalThis.Object();
                globalThis.Reflect.set(
                    labelled_item, "type", cleanLine(globalThis.Reflect.get(item, "type"), 32)
                );
                globalThis.Reflect.set(labelled_item, name, value);
                out.append(labelled_item);
                if len(out) >= cap {
                    break;
                }
            }
        }
    }
    return out;
}

# The only way details enter or leave the table: unknown keys dropped, text cleaned, lengths and counts
# capped, empty values removed. A future CSV export must neutralize formula cells (see csvSafeCell).
# The result is a plain JavaScript object.
def normalizeContactDetails(input: any = None) -> any {
    out: any = globalThis.Object();
    if not is_pair(input) {
        return out;
    }
    mails: any = globalThis.Reflect.get(input, "emails");
    if isinstance(mails, list) {
        # The first 80, read in place.
        e: list[str] = [];
        for i in range(min(len(mails), 80)) {
            if not add_email(e, mails[i]) {
                break;
            }
        }
        if len(e) > 0 {
            out["emails"] = e;
        }
    }
    p: list[any] = labelled(globalThis.Reflect.get(input, "phones"), "value", 64, 20, True);
    if len(p) > 0 {
        out["phones"] = p;
    }
    a: list[any] = labelled(
        globalThis.Reflect.get(input, "addresses"), "formatted", 500, 10, False
    );
    if len(a) > 0 {
        out["addresses"] = a;
    }
    organization: str = cleanLine(globalThis.Reflect.get(input, "organization"), 200);
    if organization {
        globalThis.Reflect.set(out, "organization", organization);
    }
    title: str = cleanLine(globalThis.Reflect.get(input, "title"), 200);
    if title {
        globalThis.Reflect.set(out, "title", title);
    }
    birthday: any = normalizeBirthday(globalThis.Reflect.get(input, "birthday"));
    if birthday is not None {
        globalThis.Reflect.set(out, "birthday", birthday);
    }
    note: str = cleanText(globalThis.Reflect.get(input, "note"), 4000);
    if note {
        globalThis.Reflect.set(out, "note", note);
    }
    return out;
}

"""The details of one card: its addresses are kept apart, as the contact's own rows."""
def withoutEmails(details: any) -> any {
    rest: any = globalThis.Object.assign(globalThis.Object(), details);
    globalThis.Reflect.deleteProperty(rest, "emails");
    return rest;
}

"""Stored details JSON, normalized again; unreadable JSON is "no details"."""
def parseStoredDetails(json: any = None) -> any {
    if not json or json.length > 64 * 1024 {
        return globalThis.Object();
    }
    try {
        return normalizeContactDetails(globalThis.JSON.parse(json));
    } except Exception {
        return globalThis.Object();
    }
}

# An import keeps a `manual` name (and source); any other name is replaced and the source becomes
# `import`, except that `outbound` stays. Without an imported name the stored one stays, null included.
def mergeImportedContact(existing: any, importedName: any = None) -> dict[str, any] {
    name = cleanLine(importedName, MAX_NAME) or NULL;
    source = field(existing, "source");
    kept = NULL if nil(existing) else existing["displayName"];
    manual = source == "manual";
    shown = kept if manual and kept and kept.trim() else either(name, kept);
    shown = shown if manual else either(shown, NULL);
    kind = source if source in ["manual", "outbound"] else "import";
    return {"displayName": shown, "source": kind};
}

# Re-import: emails, phones and addresses are united (the stored label wins); the other fields come
# from the card when it has them.
def mergeContactDetails(old: any, cur: any) -> any {
    ls = lambda (o: any, k: str) -> any { list(either(field(o, k), [])) };
    united = {k: ls(old, k) + ls(cur, k) for k in ["emails", "phones", "addresses"]};
    for k in ["organization", "title", "birthday", "note"] {
        united[k] = either(field(cur, k), field(old, k));
    }
    return normalizeContactDetails(record(united));
}

"""A stored birthday for display in `locale`: "May 1, 1980", or "May 1" when the year is unknown."""
def formatBirthday(value: str, locale: any = None) -> str {
    m = globalThis.RegExp.prototype.exec.call(STORED_BIRTHDAY, value);
    if not m {
        return value;
    }
    date = new(globalThis.Date, 0);
    n = [globalThis.Number(x) for x in m];
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
    return f"'{value}" if globalThis.RegExp.prototype.test.call(CSV_FORMULA, value) else value;
}
