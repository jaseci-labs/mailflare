# Gmail-style search grammar shared by the search box and the API: `from:maya to:"sam okoro"
# subject:invoice has:attachment is:unread is:starred after:2026-09-01 before:2026-09-30
# "exact phrase" -excluded word`. The older `title:` and bare `:unread` / `:read` forms keep working.
#
# Strings and regexes go through JavaScript's own methods, called directly, and every regex is
# made once here: Jac's dispatch and a replacer closure on every call cost more than the parsing.
# The `g` regexes are only used by `replace` and `matchAll`, which never read or leave `lastIndex`.
glob:priv OPERATOR: any = rx(
              r'(^|\s)(from|to|subject|title|has|is|after|before|newer|older|category):(?:"([^"]*)"|(\S+))',
              "gi",
          ),
          ATTACHMENT: any = rx("^attachments?$", "i"),
          UNREAD: any = rx("^unread$", "i"),
          READ: any = rx("^read$", "i"),
          STARRED: any = rx("^starred$", "i"),
          PROMOTIONS: any = rx("^promotions?$", "i"),
          PRIMARY: any = rx("^(primary|inbox)$", "i"),
          BARE_UNREAD: any = rx(r"(^|\s):unread(?=\s|$)", "i"),
          BARE_UNREAD_ALL: any = rx(r"(^|\s):unread(?=\s|$)", "gi"),
          BARE_READ: any = rx(r"(^|\s):read(?=\s|$)", "i"),
          BARE_READ_ALL: any = rx(r"(^|\s):read(?=\s|$)", "gi"),
          DATE: any = rx(r"^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$"),
          TOKEN: any = rx(r'(-?)"([^"]+)"|(-?)(\S+)', "g"),
          LEADING_DASHES: any = rx("^-+"),
          QUOTES: any = rx('"', "g"),
          SPACES: any = rx(r"\s+", "g"),
          FTS_SEPARATORS: any = rx(r"[^\p{L}\p{N}\s]+", "gu");

def:priv matches(regex: any, s: str) -> bool {
    return globalThis.RegExp.prototype.test.call(regex, s);
}

def:priv replace(s: str, regex: any, to: str) -> str {
    return globalThis.String.prototype.replace.call(s, regex, to);
}

def:priv trim(s: any) -> str {
    return globalThis.String.prototype.trim.call(s);
}

def:priv squeezed(text: str) -> str {
    return trim(replace(text, SPACES, " "));
}

def:priv parse_date(value: str, timeZone: any) -> any {
    found: any = globalThis.RegExp.prototype.exec.call(DATE, value);
    if found is NULL {
        return None;
    }
    year: int = globalThis.Number(globalThis.Reflect.get(found, 1));
    month: int = globalThis.Number(globalThis.Reflect.get(found, 2));
    day: int = globalThis.Number(globalThis.Reflect.get(found, 3));
    date: any = new(globalThis.Date, 0);
    globalThis.Date.prototype.setUTCFullYear.call(date, year, month - 1, day);
    # 2026-02-31 rolls over into March: not a date.
    y: int = globalThis.Date.prototype.getUTCFullYear.call(date);
    mo: int = globalThis.Date.prototype.getUTCMonth.call(date);
    d: int = globalThis.Date.prototype.getUTCDate.call(date);
    if y != year or mo != month - 1 or d != day {
        return None;
    }
    return dateFromZonedFields(date, normalizeTimeZone(timeZone));
}

# One `key:value` operator read into `parsed`; what replaces it in the free text.
def:priv operator(parsed: dict[str, any], zone: any, found: str, key: str, value: str) -> str {
    name: str = globalThis.String.prototype.toLowerCase.call(key);
    if name == "from" {
        parsed["from"] = value;
    } elif name == "to" {
        parsed["to"] = value;
    } elif name == "subject" or name == "title" {
        parsed["subject"] = value;
    } elif name == "has" {
        if matches(ATTACHMENT, value) {
            parsed["hasAttachment"] = True;
        }
    } elif name == "is" {
        if matches(UNREAD, value) {
            parsed["read"] = "unread";
        } elif matches(READ, value) {
            parsed["read"] = "read";
        } elif matches(STARRED, value) {
            parsed["starred"] = True;
        }
    } elif name == "category" {
        if matches(PROMOTIONS, value) {
            parsed["category"] = "promotions";
        } elif matches(PRIMARY, value) {
            parsed["category"] = "primary";
        } else {
            return found;  # an unknown value stays free text
        }
    } elif name == "after" or name == "newer" {
        parsed["after"] = either(parse_date(value, zone), parsed.get("after"));
    } elif name == "before" or name == "older" {
        parsed["before"] = either(parse_date(value, zone), parsed.get("before"));
    }
    return " ";
}

def parseSearchQuery(raw: any, timeZone: any = None) -> dict[str, any] {
    zone: any = "UTC" if timeZone is None else timeZone;
    parsed: dict[str, any] = {"text": "", "needsFullText": False};
    source: str = globalThis.String(either(raw, ""));
    # What `source.replace(OPERATOR, fn)` does, without handing JavaScript a closure: `split` puts
    # each operator's captures (lead, key, quoted, bare) between the pieces of text around it.
    rest: str = "";
    k: int = 0;
    lead: str = "";
    key: str = "";
    quoted: any = None;
    for piece in globalThis.String.prototype.split.call(source, OPERATOR) {
        if k == 0 {
            rest = rest + piece;
        } elif k == 1 {
            lead = piece;
        } elif k == 2 {
            key = piece;
        } elif k == 3 {
            quoted = piece;
        } else {
            value: str = trim(either(quoted, either(piece, "")));
            body: str = piece if quoted is None else '"' + quoted + '"';
            found: str = lead + key + ":" + body;
            rest = rest + operator(parsed, zone, found, key, value);
            k = -1;
        }
        k += 1;
    }
    if matches(BARE_UNREAD, rest) {
        parsed["read"] = "unread";
        rest = replace(rest, BARE_UNREAD_ALL, " ");
    } elif matches(BARE_READ, rest) {
        parsed["read"] = "read";
        rest = replace(rest, BARE_READ_ALL, " ");
    }
    text: str = squeezed(rest);
    parsed["text"] = text;
    full: bool = text != ""
        or globalThis.Boolean(parsed.get("from"))
        or globalThis.Boolean(parsed.get("to"))
        or globalThis.Boolean(parsed.get("subject"));
    parsed["needsFullText"] = full;
    return parsed;
}

# Split free text into phrases ("..."), negations (-word) and plain terms.
def tokenizeSearchText(text: any) -> list[dict[str, any]] {
    tokens: list[dict[str, any]] = [];
    scan(text, tokens, [], None);
    return tokens;
}

# The tokens of `text`: as dicts into `tokens` when it is given, else as FTS expressions into
# `positives`, or into `negatives` when the token is negated and `negatives` is given. `split` puts
# TOKEN's four captures (dash, phrase, dash, word) between the whitespace around each token, so no
# match array is read.
def:priv scan(text: any, tokens: any, positives: list[str], negatives: any) {
    k: int = 0;
    lead: any = None;
    quoted: any = None;
    for piece in globalThis.String.prototype.split.call(globalThis.String(text), TOKEN) {
        if k == 1 {
            lead = piece;
        } elif k == 2 {
            quoted = piece;
        } elif k == 3 {
            if quoted is None {
                lead = piece;
            }
        } elif k == 4 {
            k = -1;
            phrase: bool = quoted is not None;
            term: str = trim(quoted) if phrase else trim(replace(piece, LEADING_DASHES, ""));
            if term != "" {
                negate: bool = lead == "-";
                if tokens is not None {
                    tokens.append({"term": term, "negate": negate, "phrase": phrase});
                } else {
                    expr: str = fts_term(term, phrase);
                    if expr == "" {
                    } elif negate and negatives is not None {
                        negatives.append(expr);
                    } else {
                        positives.append(expr);
                    }
                }
            }
        }
        k += 1;
    }
}

# One term as an FTS5 string literal (quotes doubled, so input never alters the grammar). Phrases
# match whole words, plain terms by prefix ("inv" finds "invoice"); punctuation FTS5 splits on
# becomes spaces first, so "maya@acme.test" is the phrase "maya acme test".
def:priv fts_term(term: str, phrase: bool) -> str {
    cleaned: str = squeezed(replace(term, FTS_SEPARATORS, " "));
    if cleaned == "" {
        return "";
    }
    literal: str = '"' + replace(cleaned, QUOTES, '""') + '"';
    # A multi-word prefix query needs the last word starred, which FTS5 only allows inside a
    # phrase as `"a b" *`; keep it simple and require whole words.
    if phrase or globalThis.String.prototype.includes.call(cleaned, " ") {
        return literal;
    }
    return literal + "*";
}

# `parsed.k` of a parsed query: a JavaScript object from TypeScript or a Jac dict.
def:priv field(parsed: any, k: str) -> any {
    return parsed.get(k) if isinstance(parsed, dict) else globalThis.Reflect.get(parsed, k);
}

def:priv column(positives: list[str], name: str, value: any) {
    if not globalThis.Boolean(value) {
        return;
    }
    within: list[str] = [];
    scan(value, None, within, None);
    if len(within) > 0 {
        joined: str = globalThis.Array.prototype.join.call(within, " AND ");
        positives.append(name + " : (" + joined + ")");
    }
}

# FTS5 expressions for a search: column filters restrict a term to one column, free text is ANDed
# across the row. `match` holds the positive terms (negations folded in as binary NOT); `exclude`
# holds negations when no term is positive, since FTS5 has no unary NOT: callers select every row
# except those matching it. Both are null when there is nothing to match.
def buildFtsMatch(parsed: any) -> dict[str, any] {
    positives: list[str] = [];
    negatives: list[str] = [];
    scan(field(parsed, "text"), None, positives, negatives);
    column(positives, "subject", field(parsed, "subject"));
    column(positives, "from_addr", field(parsed, "from"));
    column(positives, "{to_addr cc_addr}", field(parsed, "to"));
    exclude: any = NULL;
    if len(negatives) > 0 {
        exclude = globalThis.Array.prototype.join.call(negatives, " OR ");
    }
    if len(positives) == 0 {
        return {"match": NULL, "exclude": exclude};
    }
    base: str = globalThis.Array.prototype.join.call(positives, " AND ");
    if exclude is NULL {
        return {"match": base, "exclude": NULL};
    }
    return {"match": "(" + base + ") NOT (" + exclude + ")", "exclude": NULL};
}
