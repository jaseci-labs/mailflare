"""
Gmail-style search grammar shared by the search box and the API:

  from:maya to:"sam okoro" subject:invoice has:attachment is:unread
  is:starred after:2026-09-01 before:2026-09-30 "exact phrase" -excluded word

The older `title:` and bare `:unread` / `:read` forms keep working.
"""
glob:priv OPERATOR: any = rx(
              r'(?:^|\s)(from|to|subject|title|has|is|after|before|newer|older|category):(?:"([^"]*)"|(\S+))',
              "gi",
          ),
          TEXT_FIELDS: dict[str, str] = {
              "from": "from",
              "to": "to",
              "subject": "subject",
              "title": "subject",
          },
          DATE_FIELDS: dict[str, str] = {
              "after": "after",
              "newer": "after",
              "before": "before",
              "older": "before",
          },
          # operator -> (value pattern, field, what the field becomes); the first match wins
          FLAGS: dict[str, list[tuple[str, str, any]]] = {
              "has": [("attachments?", "hasAttachment", True)],
              "is": [
                  ("unread", "read", "unread"),
                  ("read", "read", "read"),
                  ("starred", "starred", True),
              ],
              "category": [
                  ("promotions?", "category", "promotions"),
                  ("primary|inbox", "category", "primary"),
              ],
          },
          DATE: any = rx(r"^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$"),
          TOKEN: str = r'(-?)"([^"]+)"|(-?)(\S+)',
          SPACES: any = rx(r"\s+", "g"),
          FTS_SEPARATORS: any = rx(r"[^\p{L}\p{N}\s]+", "gu");

def:priv squeezed(text: str) -> str {
    return rx_sub(text, SPACES, " ").strip(" ");
}

def:priv parse_date(value: str, timeZone: any) -> any {
    found = DATE.exec(value);
    if not found {
        return None;
    }
    (year, month, day) = (
        globalThis.Number(found[1]),
        globalThis.Number(found[2]) - 1,
        globalThis.Number(found[3]),
    );
    date = new(globalThis.Date, 0);
    date.setUTCFullYear(year, month, day);
    # 2026-02-31 rolls over into March: not a date.
    if date.getUTCFullYear() != year or date.getUTCMonth() != month or date.getUTCDate() != day {
        return None;
    }
    return dateFromZonedFields(date, normalizeTimeZone(timeZone));
}

def parseSearchQuery(raw: any, timeZone: any = None) -> dict[str, any] {
    zone = "UTC" if timeZone is None else timeZone;
    parsed: dict[str, any] = {"text": "", "needsFullText": False};

    def operator(found: str, key: str, quoted: any = None, bare: any = None, *more: any) -> str {
        value: str = either(quoted, either(bare, "")).trim();
        name = key.lower();
        if name in TEXT_FIELDS {
            parsed[TEXT_FIELDS[name]] = value;
        } elif name in DATE_FIELDS {
            date = parse_date(value, zone);
            if date {
                parsed[DATE_FIELDS[name]] = date;
            }
        } else {
            for (pattern, field, becomes) in FLAGS[name] {
                if rx(f"^(?:{pattern})$", "i").test(value) {
                    parsed[field] = becomes;
                    return " ";
                }
            }
            if name == "category" {
                return found;  # an unknown value stays free text
            }
        }
        return " ";
    }

    rest: str = rx_sub(either(raw, ""), OPERATOR, operator);
    for word in ["unread", "read"] {
        bare = r"(^|\s):" + word + r"(?=\s|$)";
        if rx(bare, "i").test(rest) {
            parsed["read"] = word;
            rest = rx_sub(rest, rx(bare, "gi"), " ");
            break;
        }
    }
    parsed["text"] = squeezed(rest);
    parsed["needsFullText"] = any([parsed.get(k) for k in ["text", "from", "to", "subject"]]);
    return parsed;
}

"""Split free text into phrases ("..."), negations (-word) and plain terms."""
def tokenizeSearchText(text: any) -> list[dict[str, any]] {
    tokens: list[dict[str, any]] = [];
    for found in globalThis.Array.from(globalThis.String(text).matchAll(rx(TOKEN, "g"))) {
        phrase = found[2] is not None;
        term: str = found[2].trim() if phrase else found[4].lstrip("-").trim();
        if term {
            tokens.append({
                "term": term,
                "negate": found[1 if phrase else 3] == "-",
                "phrase": phrase,
            });
        }
    }
    return tokens;
}

"""
One term, as an FTS5 string literal: double quotes doubled, so user input can never alter the
query grammar. Phrases match whole words; plain terms match by prefix so "inv" finds "invoice".
Punctuation FTS5 treats as separators is normalised to spaces first, so "maya@acme.test"
becomes the phrase "maya acme test".
"""
def:priv fts_term(token: dict[str, any]) -> str {
    cleaned = squeezed(rx_sub(token["term"], FTS_SEPARATORS, " "));
    if not cleaned {
        return "";
    }
    literal = '"' + cleaned.replace('"', '""') + '"';
    # A multi-word prefix query needs the last word starred, which FTS5 only allows inside a
    # phrase as `"a b" *`; keep it simple and require whole words.
    return literal if token["phrase"] or " " in cleaned else f"{literal}*";
}

"""
Build the FTS5 expressions for a search. Column filters restrict a term to one column; free
text is ANDed across the whole row. `match` holds the positive terms (with any negations folded
in as FTS5's binary NOT) and `exclude` holds negations when there is no positive term, because
FTS5 has no unary NOT and a MATCH made only of negations is a syntax error: callers select
every row except those matching `exclude`. Both are null when there is nothing to match, so
callers skip the index entirely.
"""
def buildFtsMatch(parsed: any) -> dict[str, any] {
    terms = [(token["negate"], fts_term(token)) for token in tokenizeSearchText(parsed["text"])];
    positives = [expr for (negate, expr) in terms if expr and not negate];
    negatives = [expr for (negate, expr) in terms if expr and negate];
    for (column, field) in [
        ("subject", "subject"),
        ("from_addr", "from"),
        ("{to_addr cc_addr}", "to"),
    ] {
        value = at(parsed, field);
        within = [expr for token in tokenizeSearchText(value) if (expr := fts_term(token))]
            if value
            else [];
        if within {
            positives.append(f"{column} : ({' AND '.join(within)})");
        }
    }
    exclude = " OR ".join(negatives) if negatives else NULL;
    if not positives {
        return {"match": NULL, "exclude": exclude};
    }
    base = " AND ".join(positives);
    return {"match": f"({base}) NOT ({exclude})" if exclude else base, "exclude": NULL};
}
