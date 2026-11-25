# Google Contacts / Takeout CSV, current ("First Name", "E-mail 1 - Value") and legacy ("Name",
# "E-mail 1 - Type") headers. One linear pass with caps on columns, rows and field length; no
# regular expression runs on a whole file or a whole field.
#
# Strings and regexes go through JavaScript's own methods, called directly: Jac's dispatch on every
# character or cell costs more than the work. The parser jumps from one special character to the
# next and copies the text between them with one `slice`.
glob MAX_CSV_COLUMNS: int = 200,
     MAX_CSV_ROWS: int = 50000,
     MAX_CSV_FIELD: int = 10000;
glob:priv STAR: any = rx(r"^\*\s*"),
          EMAIL_COLUMN: any = rx(r"^e-?mail (\d{1,3}) - (value|label|type)$"),
          EMAIL_VALUE: any = rx(r"^e-?mail \d{1,3} - value$"),
          PHONE_COLUMN: any = rx(r"^phone (\d{1,3}) - (value|label|type)$"),
          ADDRESS_COLUMN: any = rx(r"^address (\d{1,3}) - (formatted|label|type)$"),
          NOT_LINE_BREAK: any = rx(r"[^\r\n]"),
          # The next character that is not field text outside quotes. Only `test` with an explicit
          # `lastIndex` reads it, and only in `parseCsv`, which sets `lastIndex` before each use.
          SPECIAL: any = rx("[,\\r\\n\"]", "g"),
          SEPARATOR: str = " ::: ";

"""UTF-8 (a byte order mark is dropped) or, for old Google exports that start `FF FE`, UTF-16LE."""
def decodeContactsCsv(data: any) -> str {
    utf16 = data.length >= 2 and data[0] == 0xff and data[1] == 0xfe;
    decoder = new(globalThis.TextDecoder, "utf-16le" if utf16 else "utf-8");
    return decoder.decode(data.subarray(2) if utf16 else data);
}

def:priv code_at(s: str, i: int) -> int {
    return globalThis.String.prototype.charCodeAt.call(s, i);
}

def:priv slice(s: str, a: int, b: int) -> str {
    return globalThis.String.prototype.slice.call(s, a, b);
}

def:priv max_rows(limits: any) -> any {
    if limits is None {
        return MAX_CSV_ROWS;
    }
    given: any = limits.get("maxRows") if isinstance(limits, dict) else globalThis.Reflect.get(limits, "maxRows");
    return either(given, MAX_CSV_ROWS);
}

# RFC 4180: quoted fields may hold commas, doubled quotes and line breaks; CRLF, LF and a bare CR
# end a row; blank lines are skipped. A field is cut at MAX_CSV_FIELD characters (the rest is read
# and dropped), a row at MAX_CSV_COLUMNS fields, and reading stops after `maxRows` rows, with
# `truncated` set when more followed. Indices are UTF-16 code units, as JavaScript's.
def parseCsv(text: any, limits: any = None) -> dict[str, any] {
    limit: float = globalThis.Number(max_rows(limits));
    s: str = globalThis.String(text);
    n: int = globalThis.Reflect.get(globalThis.Object(s), "length");
    rows: list[list[str]] = [];
    count: int = 0;
    row: list[str] = [];
    cells: int = 0;
    blank: bool = False;
    field: str = "";
    size: int = 0;
    quoted: bool = False;
    touched: bool = False;
    truncated: bool = False;
    i: int = 0;
    while i < n {
        if count >= limit {
            # Only blank lines after the last allowed row are not "more".
            truncated = globalThis.RegExp.prototype.test.call(NOT_LINE_BREAK, slice(s, i, n));
            break;
        }
        if quoted {
            q: int = globalThis.String.prototype.indexOf.call(s, '"', i);
            end: int = n if q < 0 else q;
            take: int = globalThis.Math.min(end - i, MAX_CSV_FIELD - size);
            if take > 0 {
                field = field + slice(s, i, i + take);
                size = size + take;
            }
            if q < 0 {
                i = n;
            } elif q + 1 < n and code_at(s, q + 1) == 34 {
                # A doubled quote inside quotes is one quote character.
                if size < MAX_CSV_FIELD {
                    field = field + '"';
                    size = size + 1;
                }
                i = q + 2;
            } else {
                quoted = False;
                i = q + 1;
            }
            continue;
        }
        globalThis.Reflect.set(SPECIAL, "lastIndex", i);
        hit: bool = globalThis.RegExp.prototype.test.call(SPECIAL, s);
        j: int = n;
        if hit {
            after: int = globalThis.Reflect.get(SPECIAL, "lastIndex");
            j = after - 1;
        }
        if j > i {
            touched = True;
            take = globalThis.Math.min(j - i, MAX_CSV_FIELD - size);
            if take > 0 {
                field = field + slice(s, i, i + take);
                size = size + take;
            }
        }
        if not hit {
            i = n;
            continue;
        }
        c: int = code_at(s, j);
        if c == 34 {
            if touched {
                if size < MAX_CSV_FIELD {
                    field = field + '"';
                    size = size + 1;
                }
            } else {
                quoted = True;
                touched = True;
            }
        } else {
            if cells < MAX_CSV_COLUMNS {
                row.append(field);
                blank = cells == 0 and field == "";
                cells = cells + 1;
            }
            field = "";
            size = 0;
            touched = False;
            if c != 44 {
                if c == 13 and j + 1 < n and code_at(s, j + 1) == 10 {
                    j = j + 1;
                }
                if not (cells == 1 and blank) {
                    rows.append(row);
                    count = count + 1;
                }
                row = [];
                cells = 0;
            }
        }
        i = j + 1;
    }
    if not truncated and (touched or field != "" or cells > 0 or quoted) {
        if cells < MAX_CSV_COLUMNS {
            row.append(field);
            blank = cells == 0 and field == "";
            cells = cells + 1;
        }
        if not (cells == 1 and blank) {
            rows.append(row);
        }
    }
    return {"rows": rows, "truncated": truncated};
}

def:priv keys_of(header: any) -> list[str] {
    names: list[str] = [];
    for name in globalThis.Array.prototype.slice.call(header, 0, MAX_CSV_COLUMNS) {
        cut: any = globalThis.String.prototype.slice.call(name, 0, 100);
        names.append(globalThis.String.prototype.toLowerCase.call(globalThis.String.prototype.trim.call(cut)));
    }
    return names;
}

"""A CSV whose header has a name column and an e-mail value column, which both Google styles do."""
def isGoogleContactsHeader(header: any) -> bool {
    names = keys_of(header);
    named = "first name" in names or "given name" in names or "name" in names;
    return named and any([EMAIL_VALUE.test(name) for name in names]);
}

"""The [value, label] columns of each numbered group (E-mail 1, E-mail 2, ...), in group order."""
def:priv slots(names: list[str], pattern: any, valueName: str) -> list[list[int]] {
    found: dict[any, any] = {};
    for (col, name) in enumerate(names) {
        hit = pattern.exec(name);
        if hit {
            slot = found.setdefault(globalThis.Number(hit[1]), [-1, -1]);
            slot[0 if hit[2] == valueName else 1] = col;
        }
    }
    return [found[k] for k in sorted(found) if found[k][0] >= 0];
}

def:priv column(names: list[str], wanted: list[str]) -> int {
    i: int = 0;
    for name in names {
        if name in wanted {
            return i;
        }
        i += 1;
    }
    return -1;
}

# The columns a mapper reads, found once per header.
obj:priv Columns {
    has full: int,
        given: list[int],
        family: list[int],
        organization: int,
        title: int,
        birthday: int,
        notes: int,
        emails: list[list[int]],
        phones: list[list[int]],
        addresses: list[list[int]];
}

# `row[i] ?? ""`, and "" for a column the header lacks.
def:priv cell(row: any, n: int, i: int) -> any {
    if i < 0 or i >= n {
        return "";
    }
    return either(row[i], "");
}

# A cell's values (`a ::: b`), at most 20, trimmed.
def:priv values_of(c: any) -> list[str] {
    out: list[str] = [];
    for part in globalThis.String.prototype.split.call(c, SEPARATOR, 20) {
        out.append(globalThis.String.prototype.trim.call(part));
    }
    return out;
}

def:priv assembled(row: any, n: int, cols: list[int]) -> any {
    parts: list[str] = [];
    for c in cols {
        part: any = cleanLine(cell(row, n, c), 100);
        if part {
            parts.append(part);
        }
    }
    return cleanLine(" ".join(parts), 100);
}

def:priv unstarred(label: any) -> any {
    return globalThis.String.prototype.replace.call(label, STAR, "");
}

# Each value of the groups with its type: its own label, else the group's first, "*" dropped.
def:priv typed(row: any, n: int, groups: list[list[int]], key: str) -> list[any] {
    out: list[any] = [];
    for group in groups {
        labels: list[str] = values_of(cell(row, n, group[1]));
        count: int = len(labels);
        p: int = 0;
        for value in values_of(cell(row, n, group[0])) {
            label: str = labels[p] if p < count else labels[0];
            item: any = globalThis.Object();
            globalThis.Reflect.set(item, key, value);
            globalThis.Reflect.set(item, "type", cleanLine(unstarred(label), 32));
            out.append(item);
            p += 1;
        }
    }
    return out;
}

def:priv mapped_row(cols: Columns, row: any) -> any {
    n: int = len(row);
    name: any = cleanLine(cell(row, n, cols.full), 100)
        or assembled(row, n, cols.given)
        or assembled(row, n, cols.family)
        or NULL;
    # The legacy export marks the primary address with a leading "*" on its type.
    starred: list[str] = [];
    plain: list[str] = [];
    for group in cols.emails {
        labels: list[str] = values_of(cell(row, n, group[1]));
        count: int = len(labels);
        p: int = 0;
        for value in values_of(cell(row, n, group[0])) {
            if value != "" {
                if p < count and globalThis.String.prototype.startsWith.call(labels[p], "*") {
                    starred.append(value);
                } else {
                    plain.append(value);
                }
            }
            p += 1;
        }
    }
    input: any = globalThis.Object();
    globalThis.Reflect.set(input, "phones", typed(row, n, cols.phones, "value"));
    globalThis.Reflect.set(input, "addresses", typed(row, n, cols.addresses, "formatted"));
    globalThis.Reflect.set(input, "organization", cell(row, n, cols.organization));
    globalThis.Reflect.set(input, "title", cell(row, n, cols.title));
    globalThis.Reflect.set(input, "birthday", cell(row, n, cols.birthday));
    globalThis.Reflect.set(input, "note", cleanText(cell(row, n, cols.notes), 4000));
    details = withoutEmails(normalizeContactDetails(input));
    ordered: list[str] = starred + plain;
    return record({"name": name, "emails": ordered[:20], "details": record(details)});
}

"""A mapper from one row to a contact for this header; build it once per file or request."""
def googleCsvMapper(header: any) -> any {
    names = keys_of(header);
    cols = Columns(
        full=column(names, ["name"]),
        given=[column(names, ["first name"]), column(names, ["middle name"]), column(names, ["last name"])],
        family=[column(names, ["given name"]), column(names, ["additional name"]), column(names, ["family name"])],
        organization=column(names, ["organization name", "organization 1 - name"]),
        title=column(names, ["organization title", "organization 1 - title"]),
        birthday=column(names, ["birthday"]),
        notes=column(names, ["notes"]),
        emails=slots(names, EMAIL_COLUMN, "value"),
        phones=slots(names, PHONE_COLUMN, "value"),
        addresses=slots(names, ADDRESS_COLUMN, "formatted"),
    );
    def mapped(row: any) -> any {
        return mapped_row(cols, row);
    }
    return mapped;
}
