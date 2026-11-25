"""
Reads the contacts CSV of Google Contacts / Takeout, in the current header style ("First Name", "E-mail 1 - Value")
and the legacy one ("Name", "Given Name", "E-mail 1 - Type"). One linear pass over the text with caps on columns, rows
and field length; no regular expression runs on a whole file or a whole field. Pure: the browser reads and previews,
the server maps the rows it is sent.
"""

glob MAX_CSV_COLUMNS: int = 200;

glob MAX_CSV_ROWS: int = 50000;

glob MAX_CSV_FIELD: int = 10000;

glob:priv MAX_HEADER_NAME: int = 100,
          SEPARATOR: str = " ::: ",
          MAX_VALUES_PER_CELL: int = 20,
          EMAIL_COLUMN: any = rx(r"^e-?mail (\d{1,3}) - (value|label|type)$"),
          PHONE_COLUMN: any = rx(r"^phone (\d{1,3}) - (value|label|type)$"),
          ADDRESS_COLUMN: any = rx(r"^address (\d{1,3}) - (formatted|label|type)$");

"""UTF-8 (a byte order mark is dropped) or, for old Google exports that start `FF FE`, UTF-16LE."""
def decodeContactsCsv(data: any) -> str {
    if data.length >= 2 and data[0] == 0xff and data[1] == 0xfe {
        return new(globalThis.TextDecoder, "utf-16le").decode(data.subarray(2));
    }
    return new(globalThis.TextDecoder, "utf-8").decode(data);
}

"""
RFC 4180: quoted fields may hold commas, doubled quotes and line breaks; CRLF, LF and a bare CR end a row; blank
lines are skipped. A field is cut at MAX_CSV_FIELD characters (the rest is read and dropped), a row at
MAX_CSV_COLUMNS fields, and reading stops after `maxRows` rows, with `truncated` set when more followed.
"""
def parseCsv(text: any, limits: any = None) -> dict[str, any] {
    maxRows = MAX_CSV_ROWS if limits is None else at(limits, "maxRows", MAX_CSV_ROWS);
    rows: list[list[str]] = [];
    row: list[str] = [];
    field: any = "";
    (quoted, touched, truncated) = (False, False, False);
    def endField {
        if len(row) < MAX_CSV_COLUMNS {
            row.append(field);
        }
        field = "";
        touched = False;
    }
    def endRow {
        endField();
        if not (len(row) == 1 and row[0] == "") {
            rows.append(row);
        }
        row = [];
    }
    size: int = text.length;
    index = 0;
    while index < size {
        if len(rows) >= maxRows {
            # Only blank lines after the last allowed row are not "more".
            rest = index;
            while rest < size and not truncated {
                truncated = text.charAt(rest) not in "\r\n";
                rest += 1;
            }
            break;
        }
        ch = text.charAt(index);
        if quoted {
            if ch != '"' {
                if field.length < MAX_CSV_FIELD {
                    field += ch;
                }
            } elif text.charAt(index + 1) == '"' {
                if field.length < MAX_CSV_FIELD {
                    field += ch;
                }
                index += 1;
            } else {
                quoted = False;
            }
        } elif ch == '"' and not touched {
            (quoted, touched) = (True, True);
        } elif ch == "," {
            endField();
        } elif ch == "\r" {
            if text.charAt(index + 1) == "\n" {
                index += 1;
            }
            endRow();
        } elif ch == "\n" {
            endRow();
        } else {
            touched = True;
            if field.length < MAX_CSV_FIELD {
                field += ch;
            }
        }
        index += 1;
    }
    if not truncated and (touched or field != "" or len(row) > 0 or quoted) {
        endRow();
    }
    return {"rows": rows, "truncated": truncated};
}

def:priv keys_of(header: any) -> list[str] {
    return [
        name.slice(0, MAX_HEADER_NAME).trim().toLowerCase()
        for name in header[:MAX_CSV_COLUMNS]
    ];
}

"""A CSV whose header has a name column and an e-mail value column, which both Google styles do."""
def isGoogleContactsHeader(header: any) -> bool {
    names = keys_of(header);
    value_column = rx(r"^e-?mail \d{1,3} - value$");
    return ("first name" in names or "given name" in names or "name" in names)
        and any([value_column.test(name) for name in names]);
}

"""The (value, label) columns of each numbered group (E-mail 1, E-mail 2, ...), in group order."""
def:priv slots(names: list[str], pattern: any, valueName: str) -> list[list[int]] {
    found: dict[int, list[int]] = {};
    for (column, name) in enumerate(names) {
        hit = pattern.exec(name);
        if not hit {
            continue;
        }
        slot = found.setdefault(globalThis.Number(hit[1]), [-1, -1]);
        slot[0 if hit[2] == valueName else 1] = column;
    }
    return [found[number] for number in sorted(found) if found[number][0] >= 0];
}

"""The values of a cell that holds several, at most 20, each trimmed."""
def:priv split(cell: str) -> list[any] {
    parts: list[any] = cell.split(SEPARATOR)[:MAX_VALUES_PER_CELL];
    return [part.trim() for part in parts];
}

"""A mapper from one row to a contact for this header; build it once per file or request."""
def googleCsvMapper(header: any) -> any {
    names = keys_of(header);
    def column(*wanted: str) -> int {
        for (index, name) in enumerate(names) {
            if name in wanted {
                return index;
            }
        }
        return -1;
    }
    full_name = column("name");
    parted = [
        [column("first name"), column("middle name"), column("last name")],
        [column("given name"), column("additional name"), column("family name")],
    ];
    organization = column("organization name", "organization 1 - name");
    title = column("organization title", "organization 1 - title");
    birthday = column("birthday");
    notes = column("notes");
    emails = slots(names, EMAIL_COLUMN, "value");
    phones = slots(names, PHONE_COLUMN, "value");
    addresses = slots(names, ADDRESS_COLUMN, "formatted");
    def mapped(row: any) -> any {
        def cell(index: int) -> any {
            return either(row[index], "") if 0 <= index < row.length else "";
        }
        def assembled(columns: list[int]) -> any {
            parts = [cleanLine(cell(c), 100) for c in columns];
            return cleanLine(" ".join([part for part in parts if part]), 100);
        }
        """Each value of a group's cells with its own label, or the group's first label when it has none."""
        def labelled(group: list[list[int]]) -> list[tuple[any, any]] {
            pairs: list[tuple[any, any]] = [];
            for slot in group {
                labels = split(cell(slot[1]));
                for (position, value) in enumerate(split(cell(slot[0]))) {
                    pairs.append((value, labels[position if position < len(labels) else 0]));
                }
            }
            return pairs;
        }
        def typed(group: list[list[int]], name: str) -> list[any] {
            return [
                record({name: value, "type": cleanLine(rx_sub(label, rx(r"^\*\s*"), ""), 32)})
                for (value, label) in labelled(group)
            ];
        }
        name = cleanLine(cell(full_name), 100)
            or assembled(parted[0])
            or assembled(parted[1])
            or NULL;
        # The legacy export marks the primary address with a leading "* " on its type.
        starred: list[any] = [];
        plain: list[any] = [];
        for slot in emails {
            labels = split(cell(slot[1]));
            for (position, value) in enumerate(split(cell(slot[0]))) {
                if value {
                    marked = position < len(labels) and labels[position].startsWith("*");
                    (starred if marked else plain).append(value);
                }
            }
        }
        details = normalizeContactDetails(
            record({
                "phones": typed(phones, "value"),
                "addresses": typed(addresses, "formatted"),
                "organization": cell(organization),
                "title": cell(title),
                "birthday": cell(birthday),
                "note": cleanText(cell(notes), 4000),
            }),
        );
        return record({
            "name": name,
            "emails": (starred + plain)[:20],
            "details": record(withoutEmails(details)),
        });
    }
    return mapped;
}
