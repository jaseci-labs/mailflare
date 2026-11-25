# 4 rows x 19 bound columns = 76 parameters, under D1's limit of 100.
glob ROWS_PER_INSERT: int = 4;

# `id IN (...)` plus the user id: 91 parameters.
glob SELECT_CHUNK: int = 90;

glob STATEMENTS_PER_BATCH: int = 50;

glob MAX_REQUEST_GROUPS: int = 50;

glob MAX_GROUP_CHARS: int = 512 * 1024;

# Rows one request may insert; a UID with many overrides counts each.
glob MAX_REQUEST_EVENTS: int = 1000;

glob:priv OWN_SUFFIX: str = "@mailflare";

type CalendarImportBody = any;

def chunk(items: any, size: int) -> list[any] {
    return [items[i:i + size] for i in range(0, len(items), size)];
}

"""The row id of one imported event: stable for (user, UID, occurrence), so a re-import finds it again."""
async def icsEventId(userId: str, uid: str, recurrenceMs: any = None) -> str {
    digest = await globalThis.crypto.subtle.digest(
        "SHA-256",
        new(globalThis.TextEncoder).encode(
            f"{userId}\n{uid}\n{globalThis.String(either(recurrenceMs, ''))}"
        ),
    );
    head = globalThis.Array.from(new(globalThis.Uint8Array, digest).subarray(0, 12));
    return "ics_" + "".join([b.toString(16).padStart(2, "0") for b in head]);
}

async def planGroupIds(userId: str, group: any) -> dict[str, any] {
    uid: any = group["uid"];
    mine = uid.endsWith(OWN_SUFFIX) and uid.length > len(OWN_SUFFIX);
    return {
        "incId": await inviteEventId(userId, uid),
        "ownId": uid.slice(0, -len(OWN_SUFFIX)) if mine else NULL,
        "masterId": await icsEventId(userId, uid, NULL) if group["master"] else NULL,
        "overrideIds": await globalThis.Promise.all([
            icsEventId(userId, uid, moved["recurrenceId"].getTime())
            for moved in group["overrides"]
        ]),
    };
}

"""Every id whose presence on the calendar matters for these groups."""
def candidateIds(planned: any) -> list[str] {
    ids: list[str] = [];
    for entry_ids in [p["ids"] for p in planned] {
        named = [entry_ids["incId"], entry_ids["ownId"], entry_ids["masterId"]];
        for id in [id for id in named if id] + list(entry_ids["overrideIds"]) {
            if id not in ids {
                ids.append(id);
            }
        }
    }
    return ids;
}

def:priv toRow(id: str, userId: str, color: str, event: any) -> any {
    return merged({
        "id": id,
        "userId": userId,
        "mailboxId": NULL,
        "title": event["title"],
        "description": event["description"],
        "location": event["location"],
        "attendees": globalThis.JSON.stringify(event["attendees"]),
        "color": color,
        "repeat": event["repeat"],
        "repeatDays": globalThis.JSON.stringify(event["repeatDays"]),
        "repeatAnchorDay": event["repeatAnchorDay"],
        "repeatUntil": event["repeatUntil"],
        "excludedOccurrences": globalThis.JSON.stringify([
            date.getTime()
            for date in event["excluded"]
        ]),
        "timeZone": event["timeZone"],
        "startsAt": event["startsAt"],
        "endsAt": event["endsAt"],
        "reminderMinutes": event["reminderMinutes"],
    });
}

"""
Decides which events to insert. A UID that already arrived as an emailed invitation, or names one of the user's own
Mailflare events, is skipped whole. Otherwise each event is skipped on its own when its import id exists, so an
import that stopped half way finishes on the next run. Imported rows carry no mailbox, invitation sender or response
status: later edits never email anyone and mail can never change them.
"""
def planCalendarImportRows(planned: any, existing: any, userId: str, color: str) -> dict[str, any] {
    rows: list[any] = [];
    (skipped, simplified, guessedZone) = (0, 0, 0);
    seen: list[str] = [];
    for item in planned {
        (group, ids) = (item["group"], item["ids"]);
        master = group["master"];
        events: list[tuple[any, any]] = [(ids["masterId"], master)]
            if master and ids["masterId"]
            else [];
        events += [(ids["overrideIds"][i], moved) for (i, moved) in enumerate(group["overrides"])];
        skipped += group["skipped"];
        if existing.has(ids["incId"]) or (ids["ownId"] and existing.has(ids["ownId"])) {
            skipped += len(events);
            continue;
        }
        added = 0;
        for (id, event) in events {
            if existing.has(id) or id in seen {
                skipped += 1;
                continue;
            }
            seen.append(id);
            rows.append(toRow(id, userId, color, event));
            added += 1;
            if event is master and group["simplified"] {
                simplified += 1;
            }
        }
        if added and group["guessedZone"] {
            guessedZone += 1;
        }
    }
    return {
        "rows": rows,
        "imported": len(rows),
        "skipped": skipped,
        "simplified": simplified,
        "guessedZone": guessedZone,
    };
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

def:priv flag_or_absent(value: any) -> bool {
    return value is None or value is True or value is False;
}

"""Checks the untrusted JSON body of POST /api/import/calendar."""
def readCalendarImportBody(body: any = None) -> dict[str, any] {
    input = object_of(body);
    source = object_of(input["source"]) if input else NULL;
    if not input or not source {
        return {"error": "Invalid request"};
    }
    name = source["name"];
    if not isinstance(name, str) or not name or name.length > 120 {
        return {"error": "Invalid calendar name"};
    }
    options = globalThis.Object() if input["options"] is None else object_of(input["options"]);
    if not options
        or not flag_or_absent(options["reminders"])
        or not flag_or_absent(options["skipDeclined"])
    {
        return {"error": "Invalid options"};
    }
    groups = input["groups"];
    if not globalThis.Array.isArray(groups)
        or groups.length < 1
        or groups.length > MAX_REQUEST_GROUPS
    {
        return {"error": f"Send 1 to {MAX_REQUEST_GROUPS} events per request"};
    }
    if not all([isinstance(group, str) and group.length <= MAX_GROUP_CHARS for group in groups]) {
        return {"error": "Invalid or oversized event"};
    }
    address = source["googleAddress"].trim().toLowerCase()
        if isinstance(source["googleAddress"], str)
        else "";
    return {
        "value": merged({
            "name": name,
            "color": source["color"] if isinstance(source["color"], str) else None,
            "googleAddress": address if address.length <= 254 and isIcsAddress(address) else None,
            "reminders": options["reminders"] is not False,
            "skipDeclined": options["skipDeclined"] is not False,
            "groups": groups,
        }),
    };
}
