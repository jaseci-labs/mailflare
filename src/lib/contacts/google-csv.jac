# Google Contacts / Takeout CSV, current ("First Name", "E-mail 1 - Value") and legacy ("Name",
# "E-mail 1 - Type") headers. One linear pass with caps on columns, rows and field length; no
# regular expression runs on a whole file or a whole field.
glob MAX_CSV_COLUMNS: int = 200,
     MAX_CSV_ROWS: int = 50000,
     MAX_CSV_FIELD: int = 10000;
glob:priv STAR: any = rx(r"^\*\s*"),
          EMAIL_COLUMN: any = rx(r"^e-?mail (\d{1,3}) - (value|label|type)$"),
          PHONE_COLUMN: any = rx(r"^phone (\d{1,3}) - (value|label|type)$"),
          ADDRESS_COLUMN: any = rx(r"^address (\d{1,3}) - (formatted|label|type)$");

"""UTF-8 (a byte order mark is dropped) or, for old Google exports that start `FF FE`, UTF-16LE."""
def decodeContactsCsv(data: any) -> str {
    utf16 = data.length >= 2 and data[0] == 0xff and data[1] == 0xfe;
    decoder = new(globalThis.TextDecoder, "utf-16le" if utf16 else "utf-8");
    return decoder.decode(data.subarray(2) if utf16 else data);
}

# RFC 4180: quoted fields may hold commas, doubled quotes and line breaks; CRLF, LF and a bare CR
# end a row; blank lines are skipped. A field is cut at MAX_CSV_FIELD characters (the rest is read
# and dropped), a row at MAX_CSV_COLUMNS fields, and reading stops after `maxRows` rows, with
# `truncated` set when more followed.
def parseCsv(text: any, limits: any = None) -> dict[str, any] {
    maxRows: int = MAX_CSV_ROWS if limits is None else either(limits["maxRows"], MAX_CSV_ROWS);
    # UTF-16 code units, as JavaScript indexes a string, in typed locals that keep the loop fast.
    chars: list[str] = globalThis.String.prototype.split.call(text, "");
    (n, i, size, field, rows, row) = (len(chars), 0, 0, "", [], []);
    (quoted, touched, truncated) = (False, False, False);
    def end_field {
        if len(row) < MAX_CSV_COLUMNS {
            row.append(field);
        }
        field = "";
        size = 0;
        touched = False;
    }
    def end_row {
        end_field();
        if not (len(row) == 1 and row[0] == "") {
            rows.append(row);
        }
        row = [];
    }
    while i < n {
        if len(rows) >= maxRows {
            # Only blank lines after the last allowed row are not "more".
            truncated = rx(r"[^\r\n]").test(text.slice(i));
            break;
        }
        ch = chars[i];
        nx = chars[i + 1] if i + 1 < n else "";
        if quoted and ch == '"' and nx != '"' {
            quoted = False;
        } elif not quoted and ch == '"' and not touched {
            (quoted, touched) = (True, True);
        } elif not quoted and ch == "," {
            # end_field inlined: this is the hot path of a long row.
            if len(row) < MAX_CSV_COLUMNS {
                row.append(field);
            }
            field = "";
            size = 0;
            touched = False;
        } elif not quoted and (ch == "\r" or ch == "\n") {
            i += 1 if ch == "\r" and nx == "\n" else 0;
            end_row();
        } else {
            # A doubled quote inside quotes is one quote character.
            i += 1 if quoted and ch == '"' else 0;
            touched = True;
            if size < MAX_CSV_FIELD {
                field += ch;
                size += 1;
            }
        }
        i += 1;
    }
    if not truncated and (touched or field != "" or len(row) > 0 or quoted) {
        end_row();
    }
    return {"rows": rows, "truncated": truncated};
}

def:priv keys_of(header: any) -> list[any] {
    return [name.slice(0, 100).trim().toLowerCase() for name in header.slice(0, MAX_CSV_COLUMNS)];
}

"""A CSV whose header has a name column and an e-mail value column, which both Google styles do."""
def isGoogleContactsHeader(header: any) -> bool {
    names = keys_of(header);
    named = "first name" in names or "given name" in names or "name" in names;
    return named and any([rx(r"^e-?mail \d{1,3} - value$").test(name) for name in names]);
}

"""The [value, label] columns of each numbered group (E-mail 1, E-mail 2, ...), in group order."""
def:priv slots(names: any, pattern: any, valueName: str) -> list[any] {
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

"""A mapper from one row to a contact for this header; build it once per file or request."""
def googleCsvMapper(header: any) -> any {
    names = keys_of(header);
    column = lambda (*w: str) -> int { ([i for (i, n) in enumerate(names) if n in w] + [-1])[0] };
    (full, birthday, notes) = (column("name"), column("birthday"), column("notes"));
    parted = [column(f"{k} name") for k in "first middle last given additional family".split()];
    organization = column("organization name", "organization 1 - name");
    title = column("organization title", "organization 1 - title");
    (emails, phones) = (slots(names, EMAIL_COLUMN, "value"), slots(names, PHONE_COLUMN, "value"));
    addresses = slots(names, ADDRESS_COLUMN, "formatted");
    def mapped(row: any) -> any {
        cell = lambda (i: int) -> any { either(row[i], "") if 0 <= i < row.length else "" };
        split = lambda (c: any) -> list[any] { [part.trim() for part in c.split(" ::: ")[:20]] };
        def assembled(cols: list[int]) -> any {
            parts = [cleanLine(cell(c), 100) for c in cols];
            return cleanLine(" ".join([p for p in parts if p]), 100);
        }
        # Each value, its type (its own label, else the group's first) and whether its label starts "*".
        def labelled(group: list[any]) -> list[any] {
            out = [];
            for (v, l) in group {
                ls = split(cell(l));
                for (p, x) in enumerate(split(cell(v))) {
                    mine = p < len(ls);
                    l = ls[p] if mine else ls[0];
                    out.append((x, cleanLine(sub(l, STAR, ""), 32), mine and l.startswith("*")));
                }
            }
            return out;
        }
        def typed(group: list[any], key: str) -> list[any] {
            return [record({key: v, "type": l}) for (v, l, _) in labelled(group)];
        }
        name = cleanLine(cell(full), 100) or assembled(parted[:3]) or assembled(parted[3:]) or NULL;
        # The legacy export marks the primary address with a leading "* " on its type.
        mails = labelled(emails);
        ordered = [v for (v, _, s) in mails if v and s] + [v for (v, _, s) in mails if v and not s];
        (o, t, b) = (cell(organization), cell(title), cell(birthday));
        base = {"phones": typed(phones, "value"), "addresses": typed(addresses, "formatted")};
        more = {"organization": o, "title": t, "birthday": b, "note": cleanText(cell(notes), 4000)};
        details = withoutEmails(normalizeContactDetails(merged(base, more)));
        return record({"name": name, "emails": ordered[:20], "details": record(details)});
    }
    return mapped;
}
