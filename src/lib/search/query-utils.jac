# Gmail-style search grammar shared by the search box and the API: `from:maya to:"sam okoro"
# subject:invoice has:attachment is:unread is:starred after:2026-09-01 before:2026-09-30
# "exact phrase" -excluded word`. The older `title:` and bare `:unread` / `:read` forms keep working.
glob:priv OPERATOR: any = rx(
              r'(?:^|\s)(from|to|subject|title|has|is|after|before|newer|older|category):(?:"([^"]*)"|(\S+))',
              "gi",
          ),
          # operator -> (value pattern, field, what the field becomes); the first match wins
          FLAGS: dict[str, list[any]] = {
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
          COLUMNS: any = {"subject": "subject", "from": "from_addr", "to": "{to_addr cc_addr}"},
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
    (year, month, day) = [globalThis.Number(found[i]) for i in [1, 2, 3]];
    date = new(globalThis.Date, 0);
    date.setUTCFullYear(year, month - 1, day);
    # 2026-02-31 rolls over into March: not a date.
    if [date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate()] != [year, month, day] {
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
        field = {"title": "subject", "newer": "after", "older": "before"}.get(name, name);
        if field in ["after", "before"] {
            parsed[field] = either(parse_date(value, zone), parsed.get(field));
        } elif field in ["from", "to", "subject"] {
            parsed[field] = value;
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

# Split free text into phrases ("..."), negations (-word) and plain terms.
def tokenizeSearchText(text: any) -> list[dict[str, any]] {
    tokens: list[dict[str, any]] = [];
    for found in globalThis.Array.from(globalThis.String(text).matchAll(rx(TOKEN, "g"))) {
        phrase = found[2] is not None;
        term: str = found[2].trim() if phrase else found[4].lstrip("-").trim();
        if term {
            negate = found[1 if phrase else 3] == "-";
            tokens.append({"term": term, "negate": negate, "phrase": phrase});
        }
    }
    return tokens;
}

# One term as an FTS5 string literal (quotes doubled, so input never alters the grammar). Phrases
# match whole words, plain terms by prefix ("inv" finds "invoice"); punctuation FTS5 splits on
# becomes spaces first, so "maya@acme.test" is the phrase "maya acme test".
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

# FTS5 expressions for a search: column filters restrict a term to one column, free text is ANDed
# across the row. `match` holds the positive terms (negations folded in as binary NOT); `exclude`
# holds negations when no term is positive, since FTS5 has no unary NOT: callers select every row
# except those matching it. Both are null when there is nothing to match.
def buildFtsMatch(parsed: any) -> dict[str, any] {
    terms = [(token["negate"], fts_term(token)) for token in tokenizeSearchText(parsed["text"])];
    positives = [expr for (negate, expr) in terms if expr and not negate];
    negatives = [expr for (negate, expr) in terms if expr and negate];
    for (field, column) in COLUMNS.items() {
        value = at(parsed, field) or "";
        within = [expr for token in tokenizeSearchText(value) if (expr := fts_term(token))];
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
