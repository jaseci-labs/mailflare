# Names the TypeScript side imports as types. A MessageActionTarget is what the server reads
# for an action target (id, mailboxId, direction, status, read, starred, folderId,
# snoozedUntil): no bodies or internal keys.
type MessageActionTarget = any;
type MessageActionPatchResult = any;
type UndoAccess = any;
type UndoRecordPlan = any;

glob:priv REVERSIBLE_STATUSES: list[str] = [
              "received",
              "sent",
              "draft",
              "queued",
              "failed",
              "trash",
              "spam",
              "archived",
          ],
          READ_ACTIONS: list[str] = ["read", "unread", "star", "unstar"],
          MANAGE_ACTIONS: list[str] = [
              "archive",
              "trash",
              "spam",
              "inbox",
              "folder",
              "snooze",
              "unsnooze",
          ],
          STATE_FIELDS: list[str] = ["status", "read", "starred", "folderId", "snoozedUntil"],
          MANAGED_FIELDS: list[str] = ["status", "folderId", "snoozedUntil"],
          # What an action writes whatever the message is.
          FIXED_PATCHES: dict[str, dict[str, any]] = {
              "archive": {"status": "archived", "folderId": NULL},
              "trash": {"status": "trash", "folderId": NULL},
              "inbox": {"status": "received", "folderId": NULL, "snoozedUntil": NULL},
              "read": {"read": True},
              "unread": {"read": False},
              "star": {"starred": True},
              "unstar": {"starred": False},
          },
          # What an action writes for inbound mail only.
          INBOUND_PATCHES: dict[str, dict[str, any]] = {
              "spam": {"status": "spam", "folderId": NULL},
              "unsnooze": {"snoozedUntil": NULL},
          };

def isReversibleMessageAction(value: any = None) -> bool {
    return isinstance(value, str) and value in READ_ACTIONS + MANAGE_ACTIONS;
}

"""Status and folder changes need manage access; read and star need read access, as before."""
def actionNeedsManage(action: any) -> bool {
    return action not in READ_ACTIONS;
}

"""The instant as an ISO string, in whole seconds as timestamps are stored in every dialect."""
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
    return {
        "status": message["status"],
        "read": message["read"],
        "starred": message["starred"],
        "folderId": message["folderId"],
        "snoozedUntil": toIsoOrNull(message["snoozedUntil"]),
    };
}

def getChangedStateFields(previous: any, applied: any) -> list[str] {
    return [field for field in STATE_FIELDS if previous[field] is not applied[field]];
}

def recordHasChanges(record: any) -> bool {
    return len(getChangedStateFields(record["previous"], record["applied"])) > 0;
}

def:priv parse_future_date(value: any) -> any {
    if not isinstance(value, str) {
        return NULL;
    }
    date = new(globalThis.Date, value);
    if globalThis.Number.isNaN(date.getTime()) or date.getTime() <= globalThis.Date.now() {
        return NULL;
    }
    return whole_second_iso(date);
}

"""The reversible fields an action writes for one message; never ownership, bodies or attachments."""
def getMessageActionPatch(action: any, given: any, message: any) -> any {
    def inbound -> bool {
        return message["direction"] == "inbound";
    }
    if action in FIXED_PATCHES {
        return {"patch": FIXED_PATCHES[action]};
    }
    if action in INBOUND_PATCHES {
        return {"patch": INBOUND_PATCHES[action]} if inbound() else {"reason": "not_applicable"};
    }
    if action == "folder" {
        folder = at(given, "folderId");
        return {"patch": {"status": "received", "folderId": folder}}
            if folder
            else {"reason": "invalid_target"};
    }
    if action == "snooze" {
        until = parse_future_date(at(given, "snoozedUntil"));
        return {"patch": {"snoozedUntil": until}}
            if until and inbound()
            else {"reason": "invalid_target"};
    }
    return None;
}

def isValidReversibleStatus(status: any = None) -> bool {
    return isinstance(status, str) and status in REVERSIBLE_STATUSES;
}

def:priv is_state_snapshot(value: any) -> bool {
    if not value or callable(value) or globalThis.Object(value) is not value {
        return False;
    }
    def text_or_null(v: any) -> bool {
        return isinstance(v, str) or v is NULL;
    }
    return isinstance(value["status"], str)
        and isinstance(value["read"], bool)
        and isinstance(value["starred"], bool)
        and text_or_null(value["folderId"])
        and text_or_null(value["snoozedUntil"]);
}

"""
Restores only the fields the action changed, and only while they still hold
its result, so a later action is never clobbered.
"""
def planUndoRecord(
    record: any, current: any, access: any, folderMailboxId: any = None
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
    needs_manage = any([field in MANAGED_FIELDS for field in fields]);
    if not access["canRead"] or (needs_manage and not access["canManage"]) {
        return skipped("forbidden");
    }
    if "status" in fields and not isValidReversibleStatus(previous["status"]) {
        return skipped("invalid_target");
    }
    if "folderId" in fields
        and previous["folderId"] is not NULL
        and (not folderMailboxId or folderMailboxId is not current["mailboxId"])
    {
        return skipped("invalid_target");
    }
    if "snoozedUntil" in fields
        and previous["snoozedUntil"] is not NULL
        and (
            current["direction"] != "inbound"
            or globalThis.Number.isNaN(new(globalThis.Date, previous["snoozedUntil"]).getTime())
        )
    {
        return skipped("invalid_target");
    }
    now = snapshotMessageState(current);
    if any([now[field] is not applied[field] for field in fields]) {
        return skipped("stale");
    }
    return {"id": id, "patch": {field: previous[field] for field in fields}, "fields": fields};
}
