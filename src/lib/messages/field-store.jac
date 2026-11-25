# The latest read/star values this tab has seen per message, so undo snapshots the screen rather
# than an older action's "applied" state; a pending overlay sits on top while its request is in
# flight, and every cache ingress applies it.
type KnownMessageFields = any;
type PendingOverlayMessage = any;
type ThreadUnreadTarget = any;

glob:priv M: any = globalThis.Math,
          FIELDS: list[str] = ["read", "starred"],
          known_fields: dict[str, dict[str, any]] = {},
          listeners: any = new(globalThis.Set),
          # row id -> {messageIds, threadUnread}; threadUnread is None while unknown, awaiting a trusted row.
          known_threads: dict[str, dict[str, any]] = {},
          # owner -> (message id -> fields, row id -> absolute unread target), oldest first.
          layers: dict[str, tuple[dict[str, dict[str, any]], dict[str, int]]] = {};

# A property that may be missing: undefined when missing, null kept as null.
def:priv opt(o: any, k: str) -> any {
    return o.get(k) if isinstance(o, dict) else getattr(o, k, None);
}

def:priv defined(source: any) -> dict[str, any] {
    return {k: opt(source, k) for k in FIELDS if opt(source, k) is not None};
}

def:priv clamp(value: any, size: int) -> int {
    return M.min(size, M.max(0, M.trunc(value))) if globalThis.Number.isFinite(value) else 0;
}

def:priv touches(row: dict[str, any], ids: any) -> bool {
    return any([id in ids for id in row["messageIds"]]);
}

def:priv tally(xs: any, want: any) -> int {
    return len([x for x in xs if x is want]);
}

def:priv notify {
    for listener in globalThis.Array.from(listeners) {
        listener();
    }
}

def rememberMessageFields(messageIds: any, patch: any) {
    seen = defined(patch);
    for id in (messageIds if seen else []) {
        known_fields[id] = {**known_fields.get(id, {}), **seen};
    }
}

# Drops optimistic member state when a rollback has no trusted snapshot.
def forgetMessageFields(messageIds: any, fields: any) {
    for id in messageIds {
        kept = {k: v for (k, v) in known_fields.get(id, {}).items() if not opt(fields, k)};
        known_fields[id] = kept;
        if not kept {
            known_fields.pop(id);
        }
    }
}

def rememberMessageRows(rows: any) {
    for row in rows {
        members = either(opt(row, "threadMessageIds"), []);
        # A grouped row's read flag is an aggregate, not the anchor's own state.
        read = None if len(members) else opt(row, "read");
        rememberMessageFields([row["id"]], {"read": read, "starred": opt(row, "starred")});
        if len(members) {
            ids = list({id: True for id in members}.keys());
            unread = clamp(either(opt(row, "threadUnread"), 0), len(ids));
            known_threads[row["id"]] = {"messageIds": ids, "threadUnread": unread};
        }
    }
}

# Any action touching a member of a known conversation joins one lock group.
def getConversationLockKeys(ids: any) -> list[str] {
    keys: dict[str, bool] = {id: True for id in ids};
    for (rowId, row) in known_threads.items() {
        if rowId in keys or touches(row, keys) {
            keys.update({id: True for id in [rowId] + row["messageIds"]});
        }
    }
    return list(keys.keys());
}

def getThreadRowIdsForMessages(ids: any) -> list[str] {
    return [rowId for (rowId, row) in known_threads.items() if touches(row, ids)];
}

# Persists a server-confirmed aggregate even when its list row is not cached.
def rememberThreadUnreadTargets(targets: any) {
    for (rowId, unread) in targets.items() {
        row = known_threads.get(rowId);
        if row is not None and globalThis.Number.isFinite(unread) {
            row["threadUnread"] = clamp(unread, len(row["messageIds"]));
        }
    }
}

# Keeps conversation membership for locking but drops an untrusted aggregate.
def invalidateThreadUnreadTargets(rowIds: any) {
    for rowId in [r for r in rowIds if r in known_threads] {
        known_threads[rowId]["threadUnread"] = None;
    }
}

def:priv as_map(pairs: any) -> any {
    return new(globalThis.Map, [[k, v] for (k, v) in pairs.items()]);
}

# A `def`'s result reaches JavaScript with every Map made a plain object, so these return real Maps.
glob getPendingThreadTargets: any = lambda (owner: str) -> any {
         as_map(layers[owner][1] if owner in layers else {})
     },
     # Pre-click grouped unread aggregates for rollback after a failed undo.
     captureThreadUnread: any = lambda (ids: any) -> any { as_map(thread_unread_of(ids)) },
     # Copies only fields this tab has actually observed; unknown ids stay unknown.
     captureMessageFields: any = lambda (ids: any) -> any {
         as_map({id: merged(seen) for id in ids if (seen := getVisibleMessageFields(id))})
     };

# Latest known value including any active pending operation.
def getVisibleMessageFields(messageId: str) -> dict[str, any] {
    fields = dict(known_fields.get(messageId, {}));
    for (messages, _) in layers.values() {
        fields.update(messages.get(messageId, {}));
    }
    return fields;
}

# The newest owner's target wins over the known aggregate.
def getKnownThreadUnread(rowId: str) -> any {
    hits = [t[rowId] for (_, t) in layers.values() if rowId in t];
    return hits[-1] if hits else known_threads.get(rowId, {}).get("threadUnread");
}

# Applies every active owner's overlay; later owners win field by field. A row no overlay changed
# comes back as itself.
def applyPendingToMessage(message: any) -> any {
    (id, members) = (message["id"], either(opt(message, "threadMessageIds"), []));
    now = {k: opt(message, k) for k in ["read", "starred", "threadUnread"]};
    changed = False;
    for (messages, threads) in layers.values() {
        step = dict(messages.get(id, {}));
        if len(members) and id in threads {
            step["threadUnread"] = clamp(threads[id], len(members));
        }
        changed = changed or any([now[k] is not v for (k, v) in step.items()]);
        now.update(step);
    }
    if not changed {
        return message;
    }
    out = merged(message, {k: v for (k, v) in now.items() if v is not None});
    if len(members) and now["threadUnread"] is not None {
        out["read"] = now["threadUnread"] == 0;
    }
    return out;
}

def applyPendingToMessages(messages: any) -> any {
    applied = [applyPendingToMessage(m) for m in messages];
    return applied if any([a is not m for (a, m) in zip(applied, messages)]) else messages;
}

def applyPendingToMessageList(response: any) -> any {
    rows = either(opt(response, "messages"), []);
    messages = applyPendingToMessages(rows) if len(rows) else rows;
    return response if messages is rows else merged(response, {"messages": messages});
}

def setPendingOverlay(owner: str, entries: any) {
    if not owner {
        return;
    }
    messages: dict[str, dict[str, any]] = {};
    threads: dict[str, int] = {};
    for item in at(entries, "messages", []) {
        if (seen := defined(item)) {
            messages[item["id"]] = {**messages.get(item["id"], {}), **seen};
        }
    }
    for item in at(entries, "threads", []) {
        if globalThis.Number.isFinite(item["threadUnread"]) {
            threads[item["id"]] = M.max(0, M.trunc(item["threadUnread"]));
        }
    }
    if not messages and not threads {
        clearPendingOverlay(owner);
        return;
    }
    # An existing owner keeps its position, so a newer operation stays last.
    layers[owner] = (messages, threads);
    notify();
}

def clearPendingOverlay(owner: str) -> bool {
    if owner not in layers {
        return False;
    }
    layers.pop(owner);
    notify();
    return True;
}

def hasPendingOverlay -> bool {
    return len(layers) > 0;
}

def getPendingOverlayOwners -> list[str] {
    return list(layers.keys());
}

def subscribePendingOverlay(listener: any) -> any {
    listeners.add(listener);
    return lambda -> any { listeners.delete(listener) };
}

# Absolute unread targets: only real member transitions, bounded by the aggregate.
def getThreadUnreadTargets(fields: any) -> list[dict[str, any]] {
    reads = {f["id"]: opt(f, "read") for f in fields if opt(f, "read") is not None};
    targets: list[dict[str, any]] = [];
    for (rowId, row) in known_threads.items() {
        agg = getKnownThreadUnread(rowId);
        if agg is None or not touches(row, reads) {
            continue;
        }
        n = len(row["messageIds"]);
        cur = clamp(agg, n);
        vis = {id: getVisibleMessageFields(id).get("read") for id in row["messageIds"]};
        asked = [(vis[id], reads[id]) for id in vis if id in reads];
        # A known member flips directly; unknown ones only as far as the aggregate leaves room.
        unknown = [bool(d) for (v, d) in asked if v is None];
        direct = [bool(d) for (v, d) in asked if v is not None and v is not d];
        seen = list(vis.values());
        room = (max(0, cur - tally(seen, False)), max(0, n - cur - tally(seen, True)));
        to_read = tally(direct, True) + min(tally(unknown, True), room[0]);
        to_unread = tally(direct, False) + min(tally(unknown, False), room[1]);
        targets.append({"id": rowId, "threadUnread": clamp(cur - to_read + to_unread, n)});
    }
    return targets;
}

def:priv thread_unread_of(ids: any) -> dict[str, int] {
    return {
        rowId: clamp(visible, len(row["messageIds"]))
        for (rowId, row) in known_threads.items()
        if touches(row, ids) and (visible := getKnownThreadUnread(rowId)) is not None
    };
}

def clearKnownMessageFieldsForTests {
    known_fields.clear();
    known_threads.clear();
    layers.clear();
}
