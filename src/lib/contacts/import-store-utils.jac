# Cards (or CSV rows) one request may carry.
glob MAX_REQUEST_ITEMS: int = 100;

# Contact rows one request may write: a card with several addresses writes one row per address.
glob MAX_REQUEST_ADDRESSES: int = 400;

# `contacts` has 10 columns: 8 rows are 80 bound parameters, under D1's limit of 100.
glob CONTACTS_PER_INSERT: int = 8;

# `contact_details` has 3 columns.
glob DETAILS_PER_INSERT: int = 30;

# `id IN (...)` plus the user id: 91 parameters.
glob SELECT_CHUNK: int = 90;

glob STATEMENTS_PER_BATCH: int = 50;

def chunk(items: any, size: int) -> list[any] {
    return [items[i:i + size] for i in range(0, len(items), size)];
}

"""A JSON object (not null, not an array), else null."""
def:priv object_of(value: any) -> any {
    return value
        if not nil(value)
            and globalThis.Object(value) is value
            and not globalThis.Array.isArray(value)
            and not globalThis.Function.prototype.isPrototypeOf(value)
        else NULL;
}

"""An array of at most `limit` strings, none longer than `width`."""
def:priv strings(value: any, limit: int, width: int) -> bool {
    return globalThis.Array.isArray(value)
        and value.length <= limit
        and all([isinstance(item, str) and item.length <= width for item in value]);
}

def:priv countable(items: any) -> bool {
    return globalThis.Array.isArray(items) and 1 <= items.length <= MAX_REQUEST_ITEMS;
}

"""Checks the untrusted JSON body of POST /api/import/contacts."""
def readContactImportBody(body: any = None) -> dict[str, any] {
    input = object_of(body);
    mailboxId = input["mailboxId"] if input else None;
    if not isinstance(mailboxId, str) or not mailboxId or mailboxId.length > 200 {
        return {"error": "A mailbox is required"};
    }
    too_many: dict[str, any] = {"error": f"Send 1 to {MAX_REQUEST_ITEMS} contacts per request"};
    if input["format"] == "vcard" {
        items = input["items"];
        if input["csv"] is not None or not countable(items) {
            return too_many;
        }
        cards: list[any] = [];
        for item in items {
            card = object_of(item);
            if not card
                or not isinstance(card["vcard"], str)
                or card["vcard"].length > MAX_CARD_CHARS
                or not (card["hasPhoto"] is True or card["hasPhoto"] is False)
            {
                return {"error": "Invalid or oversized contact"};
            }
            cards.append({"vcard": card["vcard"], "hasPhoto": card["hasPhoto"]});
        }
        return {"value": {"mailboxId": mailboxId, "format": "vcard", "items": cards}};
    }
    if input["format"] == "google-csv" {
        csv = object_of(input["csv"]);
        if input["items"] is not None
            or not csv
            or not strings(csv["header"], MAX_CSV_COLUMNS, MAX_CSV_FIELD)
        {
            return {"error": "Invalid CSV header"};
        }
        rows = csv["rows"];
        if not countable(rows) {
            return too_many;
        }
        if not all([strings(row, MAX_CSV_COLUMNS, MAX_CSV_FIELD) for row in rows]) {
            return {"error": "Invalid CSV row"};
        }
        return {
            "value": {
                "mailboxId": mailboxId,
                "format": "google-csv",
                "csv": {"header": csv["header"], "rows": rows},
            },
        };
    }
    return {"error": "Unknown format"};
}

"""The cards of a validated body. Never throws: bad text becomes a card without addresses."""
def parseContactImportCards(body: any) -> list[any] {
    if at(body, "format") == "vcard" {
        return [
            {"contact": parseVcard(item["vcard"]), "hasPhoto": item["hasPhoto"]}
            for item in at(body, "items", [])
        ];
    }
    csv = at(body, "csv");
    mapped = googleCsvMapper(at(csv, "header", []) if csv else []);
    return [
        {"contact": mapped(row), "hasPhoto": False}
        for row in (at(csv, "rows", []) if csv else [])
    ];
}

def:priv json(details: any) -> str {
    return globalThis.JSON.stringify(record(details));
}

"""
Decides what an import writes, without touching the database. Every address on a card becomes or updates one contact.
An existing contact keeps a name set in the address book and takes the imported name otherwise (see
mergeImportedContact); blocked and remote-content settings are never part of a plan. A card's details are merged
into the stored ones (mergeContactDetails) and written when that changes them, so importing the same file again
plans nothing. A card with a single address and no other detail writes no details row and leaves an existing one
alone. A photo is never planned for an address in `ownAddresses` (the user's own identities).
"""
def planContactImport(input: any) -> dict[str, any] {
    userId = input["userId"];
    ownAddresses = at(input, "ownAddresses");
    states: dict[str, dict[str, any]] = {};
    photoTargets: list[str] = [];
    (noEmail, addresses) = (0, 0);
    def stateOf(email: str) -> dict[str, any] {
        id = getContactId(userId, email);
        if id not in states {
            found = input["existing"].get(id);
            stored = input["existingDetails"].get(id);
            details: any = NULL if stored is None else json(parseStoredDetails(stored));
            displayName = either(found["displayName"], NULL) if found else NULL;
            source = either(found["source"], "import") if found else "import";
            states[id] = {
                "email": email,
                "exists": bool(found),
                "displayName": displayName,
                "source": source,
                "avatarKey": either(found["avatarKey"], NULL) if found else NULL,
                "detailsExist": stored is not None,
                "touched": False,
                "before": (displayName, source, details),
                "details": details,
            };
        }
        return states[id];
    }
    for card in input["cards"] {
        contact = card["contact"];
        emails = importedContactEmails(contact["emails"]);
        if not emails {
            noEmail += 1;
            continue;
        }
        addresses += len(emails);
        if addresses > MAX_REQUEST_ADDRESSES {
            raise new(RequestBodyTooLargeError, "Too many addresses in one request");
        }
        details = normalizeContactDetails(merged(contact["details"], {"emails": emails}));
        bare = len(emails) <= 1 and len(details) == 1;
        for email in emails {
            state = stateOf(email);
            known = state["exists"] or state["touched"];
            name = mergeImportedContact(
                record({"displayName": state["displayName"], "source": state["source"]})
                    if known
                    else NULL,
                contact["name"],
            );
            state["displayName"] = name["displayName"];
            state["source"] = name["source"];
            if not bare {
                kept = parseStoredDetails(state["details"]) if state["details"] else NULL;
                state["details"] = json(mergeContactDetails(kept, details));
            }
            state["touched"] = True;
        }
        # Never the user's own profile picture: an own identity address is not a photo target.
        first = emails[0];
        if card["hasPhoto"]
            and not stateOf(first)["avatarKey"]
            and not (ownAddresses and ownAddresses.has(first))
            and first not in photoTargets
        {
            photoTargets.append(first);
        }
    }
    contacts: list[any] = [];
    renames: list[any] = [];
    detailInserts: list[any] = [];
    detailUpdates: list[any] = [];
    (created, updated, unchanged) = (0, 0, 0);
    for (id, state) in states.items() {
        (name, source) = (state["displayName"], state["source"]);
        (old_name, old_source, old_details) = state["before"];
        changed = state["details"] is not NULL and state["details"] != old_details;
        details = {"contactId": id, "details": state["details"], "updatedAt": input["now"]};
        if not state["exists"] {
            created += 1;
            contacts.append({
                "id": id,
                "userId": userId,
                "email": state["email"],
                "displayName": name,
                "source": source,
            });
            if changed {
                detailInserts.append(details);
            }
            continue;
        }
        renamed = name != old_name or source != old_source;
        if renamed {
            renames.append({"id": id, "displayName": name, "source": source});
        }
        if changed {
            (detailUpdates if state["detailsExist"] else detailInserts).append(details);
        }
        if renamed or changed {
            updated += 1;
        } else {
            unchanged += 1;
        }
    }
    return {
        "contacts": contacts,
        "renames": renames,
        "detailInserts": detailInserts,
        "detailUpdates": detailUpdates,
        "created": created,
        "updated": updated,
        "unchanged": unchanged,
        "noEmail": noEmail,
        "photoTargets": photoTargets,
    };
}
