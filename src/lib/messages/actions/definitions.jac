# What the server reads for an action target: no bodies or internal keys.
type MessageActionTarget = any;

glob:priv STATUSES: list[str] = "received sent draft queued failed trash spam archived".split();

glob:priv READ_ACTIONS: list[str] = "read unread star unstar".split();

glob:priv MANAGE_ACTIONS: list[str] = "archive trash spam inbox folder snooze unsnooze".split();

glob:priv STATE_FIELDS: list[str] = "status read starred folderId snoozedUntil".split();

# What an action writes whatever the message is.
glob:priv FIXED_PATCHES: dict[str, dict[str, any]] = {
    "archive": {"status": "archived", "folderId": NULL},
    "trash": {"status": "trash", "folderId": NULL},
    "inbox": {"status": "received", "folderId": NULL, "snoozedUntil": NULL},
    "read": {"read": True},
    "unread": {"read": False},
    "star": {"starred": True},
    "unstar": {"starred": False},
};

# What an action writes for inbound mail only.
glob:priv INBOUND_PATCHES: dict[str, dict[str, any]] = {
    "spam": {"status": "spam", "folderId": NULL},
    "unsnooze": {"snoozedUntil": NULL},
};

def isReversibleMessageAction(value: any = None) -> bool {
    return isinstance(value, str) and value in READ_ACTIONS + MANAGE_ACTIONS;
}

# Status and folder changes need manage access; read and star need read access, as before.
def actionNeedsManage(action: any) -> bool {
    return action not in READ_ACTIONS;
}

# Timestamps are stored as whole seconds in every dialect.
def:priv whole_second_iso(date: any) -> str {
    return new(globalThis.Date, globalThis.Math.floor(date.getTime() / 1000) * 1000).toISOString();
}

def toIsoOrNull(value: any = None) -> any {
    if not value {
        return NULL;
    }
    date = value if isinstance(value, globalThis.Date) else new(globalThis.Date, value);
    return NULL if globalThis.Number.isNaN(date.getTime()) else whole_second_iso(date);
}

def snapshotMessageState(message: any) -> dict[str, any] {
    s = {k: message[k] for k in STATE_FIELDS};
    return {**s, "snoozedUntil": toIsoOrNull(message["snoozedUntil"])};
}

def getChangedStateFields(previous: any, applied: any) -> list[str] {
    return [field for field in STATE_FIELDS if previous[field] is not applied[field]];
}

def recordHasChanges(record: any) -> bool {
    return len(getChangedStateFields(record["previous"], record["applied"])) > 0;
}

def:priv parse_future_date(value: any) -> any {
    date = new(globalThis.Date, value) if isinstance(value, str) else None;
    bad = date is None or globalThis.Number.isNaN(date.getTime());
    return NULL if bad or date.getTime() <= globalThis.Date.now() else whole_second_iso(date);
}

# The reversible fields an action writes for one message; never ownership, bodies or attachments.
def getMessageActionPatch(action: any, given: any, message: any) -> any {
    if action in FIXED_PATCHES {
        return {"patch": FIXED_PATCHES[action]};
    }
    if action in INBOUND_PATCHES {
        inbound = message["direction"] == "inbound";
        return {"patch": INBOUND_PATCHES[action]} if inbound else {"reason": "not_applicable"};
    }
    bad = {"reason": "invalid_target"};
    if action == "folder" {
        f = at(given, "folderId");
        return {"patch": {"status": "received", "folderId": f}} if f else bad;
    }
    if action == "snooze" {
        until = parse_future_date(at(given, "snoozedUntil"));
        ok = until and message["direction"] == "inbound";
        return {"patch": {"snoozedUntil": until}} if ok else bad;
    }
    return None;
}

def isValidReversibleStatus(status: any = None) -> bool {
    return isinstance(status, str) and status in STATUSES;
}

def:priv is_state_snapshot(v: any) -> bool {
    if not is_object(v) {
        return False;
    }
    flags = all([isinstance(v[k], bool) for k in ["read", "starred"]]);
    nullable = all([isinstance(v[k], str) or v[k] is NULL for k in ["folderId", "snoozedUntil"]]);
    return isinstance(v["status"], str) and flags and nullable;
}

# Restores only the fields the action changed, and only while they still hold its result, so a
# later action is never clobbered.
def planUndoRecord(
    record: any, current: any, access: any, folderBox: any = None
) -> dict[str, any] {
    (id, previous, applied) = (record["id"], record["previous"], record["applied"]);
    def skipped(reason: str) -> dict[str, any] {
        return {"id": id, "reason": reason};
    }
    if id is not current["id"] {
        return skipped("not_found");
    }
    if not record["mailboxId"] or record["mailboxId"] is not current["mailboxId"] {
        return skipped("forbidden");
    }
    if not is_state_snapshot(previous) or not is_state_snapshot(applied) {
        return skipped("invalid_target");
    }
    fields = getChangedStateFields(previous, applied);
    if not fields {
        return skipped("not_applicable");
    }
    needs_manage = any([f in ["status", "folderId", "snoozedUntil"] for f in fields]);
    if not access["canRead"] or (needs_manage and not access["canManage"]) {
        return skipped("forbidden");
    }
    until = previous["snoozedUntil"];
    bad_date = globalThis.Number.isNaN(new(globalThis.Date, until).getTime());
    bad = {
        "status": not isValidReversibleStatus(previous["status"]),
        "folderId": previous["folderId"] is not NULL
            and (not folderBox or folderBox is not current["mailboxId"]),
        "snoozedUntil": until is not NULL and (current["direction"] != "inbound" or bad_date),
    };
    if any([bad[f] for f in fields if f in bad]) {
        return skipped("invalid_target");
    }
    now = snapshotMessageState(current);
    if any([now[f] is not applied[f] for f in fields]) {
        return skipped("stale");
    }
    return {"id": id, "patch": {f: previous[f] for f in fields}, "fields": fields};
}
