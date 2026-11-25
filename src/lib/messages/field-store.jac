"""
The latest read/star values this tab has seen per message, so undo snapshots the screen rather
than an older action's "applied" state. A pending overlay sits on top while its request is in
flight and every cache ingress applies it.
"""
# Names the TypeScript side imports as types.
type KnownMessageFields = any;
type PendingOverlayMessage = any;
type ThreadUnreadTarget = any;
type PendingOverlayEntries = any;

glob:priv FIELDS: list[str] = ["read", "starred"],
          # message id -> the read/starred values seen (only those that are known)
          known_fields: dict[str, dict[str, any]] = {},
          # grouped row id -> {messageIds, threadUnread}; threadUnread is None while the
          # aggregate is unknown and awaiting an authoritative row
          known_threads: dict[str, dict[str, any]] = {},
          # owner -> (message id -> fields, grouped row id -> absolute unread target), oldest first
          pending_layers: dict[str, tuple[dict[str, dict[str, any]], dict[str, int]]] = {},
          pending_listeners: list[any] = [];

"""A property of a record that may lack it: undefined when missing, null kept as null."""
def:priv opt(o: any, k: str) -> any {
    return o.get(k) if isinstance(o, dict) else getattr(o, k, None);
}

"""The read/starred values a record actually carries."""
def:priv defined(source: any) -> dict[str, any] {
    return {k: opt(source, k) for k in FIELDS if opt(source, k) is not None};
}

def:priv clamp_count(value: any, size: int) -> int {
    if not globalThis.Number.isFinite(value) {
        return 0;
    }
    return globalThis.Math.min(size, globalThis.Math.max(0, globalThis.Math.trunc(value)));
}

def:priv touches(row: dict[str, any], ids: any) -> bool {
    return any([id in ids for id in row["messageIds"]]);
}

def:priv notify_pending_listeners {
    for listener in list(pending_listeners) {
        listener();
    }
}

def rememberMessageFields(messageIds: any, patch: any) {
    seen = defined(patch);
    if not seen {
        return;
    }
    for id in messageIds {
        known_fields[id] = {**known_fields.get(id, {}), **seen};
    }
}

"""Drops optimistic member state when a rollback has no trusted snapshot."""
def forgetMessageFields(messageIds: any, fields: any) {
    for id in messageIds {
        if id not in known_fields {
            continue;
        }
        current = known_fields[id];
        for k in FIELDS {
            if opt(fields, k) {
                current.pop(k, None);
            }
        }
        if not current {
            known_fields.pop(id);
        }
    }
}

def rememberMessageRows(rows: any) {
    for row in rows {
        members = opt(row, "threadMessageIds");
        grouped = not nil(members) and len(members) > 0;
        # A grouped row's read flag is an aggregate, not the anchor's own state.
        rememberMessageFields(
            [row["id"]],
            {"read": None if grouped else opt(row, "read"), "starred": opt(row, "starred")},
        );
        if grouped {
            ids = list({id: True for id in members}.keys());
            known_threads[row["id"]] = {
                "messageIds": ids,
                "threadUnread": clamp_count(either(opt(row, "threadUnread"), 0), len(ids)),
            };
        }
    }
}

"""Any action touching a member of a known conversation joins one lock group."""
def getConversationLockKeys(ids: any) -> list[str] {
    keys: dict[str, bool] = {id: True for id in ids};
    for (rowId, row) in known_threads.items() {
        if rowId in keys or touches(row, keys) {
            keys[rowId] = True;
            keys.update({id: True for id in row["messageIds"]});
        }
    }
    return list(keys.keys());
}

"""Grouped rows containing any of these message ids."""
def getThreadRowIdsForMessages(ids: any) -> list[str] {
    wanted = set(ids);
    return [rowId for (rowId, row) in known_threads.items() if touches(row, wanted)];
}

"""Persists a server-confirmed aggregate even when its list row is not cached."""
def rememberThreadUnreadTargets(targets: any) {
    for (rowId, unread) in targets.items() {
        if rowId in known_threads and globalThis.Number.isFinite(unread) {
            row = known_threads[rowId];
            row["threadUnread"] = clamp_count(unread, len(row["messageIds"]));
        }
    }
}

"""Keeps conversation membership for locking but drops an untrusted aggregate."""
def invalidateThreadUnreadTargets(rowIds: any) {
    for rowId in rowIds {
        if rowId in known_threads {
            known_threads[rowId]["threadUnread"] = None;
        }
    }
}

def:priv pending_fields_for(messageId: str) -> dict[str, any] {
    fields: dict[str, any] = {};
    for (messages, _) in pending_layers.values() {
        fields.update(messages.get(messageId, {}));
    }
    return fields;
}

def:priv as_map(pairs: any) -> any {
    return new(globalThis.Map, [[k, v] for (k, v) in pairs.items()]);
}

# What a `def` returns reaches JavaScript with every Map turned into a plain object. The three
# functions whose callers need a real Map are therefore exported as function values.
glob getPendingThreadTargets: any = lambda (owner: str) -> any {
         as_map(pending_layers[owner][1] if owner in pending_layers else {})
     },
     # Pre-click grouped unread aggregates for rollback after a failed undo.
     captureThreadUnread: any = lambda (ids: any) -> any { as_map(thread_unread_of(ids)) },
     # Copies only fields this tab has actually observed; unknown ids stay unknown.
     captureMessageFields: any = lambda (ids: any) -> any {
         as_map({id: merged(seen) for id in ids if (seen := getVisibleMessageFields(id))})
     };

"""Latest known value including any active pending operation."""
def getVisibleMessageFields(messageId: str) -> dict[str, any] {
    return {**known_fields.get(messageId, {}), **pending_fields_for(messageId)};
}

"""Latest visible unread aggregate for a grouped conversation row: the newest owner's target wins."""
def getKnownThreadUnread(rowId: str) -> any {
    for (_, threads) in reversed(list(pending_layers.values())) {
        if rowId in threads {
            return threads[rowId];
        }
    }
    return known_threads[rowId]["threadUnread"] if rowId in known_threads else None;
}

"""Applies every active owner's overlay; later owners win field by field."""
def applyPendingToMessage(message: any) -> any {
    (read, starred, unread) = (
        opt(message, "read"),
        opt(message, "starred"),
        opt(message, "threadUnread"),
    );
    members = opt(message, "threadMessageIds");
    size = 0 if nil(members) else len(members);
    changed = False;
    for (messages, threads) in pending_layers.values() {
        fields = messages.get(message["id"], {});
        if "read" in fields and read is not fields["read"] {
            (read, changed) = (fields["read"], True);
        }
        if "starred" in fields and starred is not fields["starred"] {
            (starred, changed) = (fields["starred"], True);
        }
        if size and message["id"] in threads {
            target = clamp_count(threads[message["id"]], size);
            if unread is not target {
                (unread, changed) = (target, True);
            }
        }
    }
    if not changed {
        return message;
    }
    following = merged(message);
    if read is not None {
        following["read"] = read;
    }
    if starred is not None {
        following["starred"] = starred;
    }
    if unread is not None {
        following["threadUnread"] = unread;
        if size {
            following["read"] = unread == 0;
        }
    }
    return following;
}

"""The same array when no overlay touched a row, so callers can compare by identity."""
def applyPendingToMessages(messages: any) -> any {
    applied = [applyPendingToMessage(message) for message in messages];
    return applied
        if any([applied[i] is not messages[i] for i in range(len(applied))])
        else messages;
}

def applyPendingToMessageList(response: any) -> any {
    rows = opt(response, "messages");
    if nil(rows) or len(rows) == 0 {
        return response;
    }
    messages = applyPendingToMessages(rows);
    return response if messages is rows else merged(response, {"messages": messages});
}

def setPendingOverlay(owner: str, entries: any) {
    if not owner {
        return;
    }
    messages: dict[str, dict[str, any]] = {};
    for item in at(entries, "messages", []) {
        seen = defined(item);
        if seen {
            messages[item["id"]] = {**messages.get(item["id"], {}), **seen};
        }
    }
    threads: dict[str, int] = {};
    for item in at(entries, "threads", []) {
        if globalThis.Number.isFinite(item["threadUnread"]) {
            threads[item["id"]] = globalThis.Math.max(
                0, globalThis.Math.trunc(item["threadUnread"])
            );
        }
    }
    if not messages and not threads {
        clearPendingOverlay(owner);
        return;
    }
    # An existing owner keeps its position, so a newer operation stays last.
    pending_layers[owner] = (messages, threads);
    notify_pending_listeners();
}

def clearPendingOverlay(owner: str) -> bool {
    if owner not in pending_layers {
        return False;
    }
    pending_layers.pop(owner);
    notify_pending_listeners();
    return True;
}

def hasPendingOverlay -> bool {
    return len(pending_layers) > 0;
}

def getPendingOverlayOwners -> list[str] {
    return list(pending_layers.keys());
}

def subscribePendingOverlay(listener: any) -> any {
    if listener not in pending_listeners {
        pending_listeners.append(listener);
    }
    def unsubscribe -> bool {
        if listener not in pending_listeners {
            return False;
        }
        pending_listeners.remove(listener);
        return True;
    }
    return unsubscribe;
}

"""Absolute unread targets: only real member transitions, bounded by the aggregate."""
def getThreadUnreadTargets(fields: any) -> list[dict[str, any]] {
    reads: dict[str, any] = {
        field["id"]: opt(field, "read")
        for field in fields
        if opt(field, "read") is not None
    };
    targets: list[dict[str, any]] = [];
    if not reads {
        return targets;
    }
    for (rowId, row) in known_threads.items() {
        aggregate = getKnownThreadUnread(rowId);
        if aggregate is None or not touches(row, reads) {
            continue;
        }
        size = len(row["messageIds"]);
        current = clamp_count(aggregate, size);
        # Members whose state this tab knows, and the transitions asked for: direct ones flip a
        # known member, unknown ones are bounded below by what the aggregate leaves room for.
        (
            known_unread,
            known_read,
            direct_to_read,
            direct_to_unread,
            unknown_unread,
            unknown_read,
        ) = (0, 0, 0, 0, 0, 0);
        for id in row["messageIds"] {
            visible = getVisibleMessageFields(id).get("read");
            known_unread += 1 if visible is False else 0;
            known_read += 1 if visible is True else 0;
            if id not in reads {
                continue;
            }
            desired = bool(reads[id]);
            if visible is None {
                unknown_unread += 1 if desired else 0;
                unknown_read += 0 if desired else 1;
            } elif visible is not reads[id] {
                direct_to_read += 1 if desired else 0;
                direct_to_unread += 0 if desired else 1;
            }
        }
        to_read = direct_to_read + min(unknown_unread, max(0, current - known_unread));
        to_unread = direct_to_unread + min(unknown_read, max(0, size - current - known_read));
        targets.append({
            "id": rowId,
            "threadUnread": clamp_count(current - to_read + to_unread, size),
        });
    }
    return targets;
}

def:priv thread_unread_of(ids: any) -> dict[str, int] {
    wanted = set(ids);
    return {
        rowId: clamp_count(visible, len(row["messageIds"]))
        for (rowId, row) in known_threads.items()
        if (visible := getKnownThreadUnread(rowId)) is not None and touches(row, wanted)
    };
}

"""Test-only reset."""
def clearKnownMessageFieldsForTests {
    known_fields.clear();
    known_threads.clear();
    pending_layers.clear();
}
