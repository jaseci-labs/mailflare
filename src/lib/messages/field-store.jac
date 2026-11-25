# The latest read/star values this tab has seen per message, so undo snapshots the screen rather
# than an older action's "applied" state; a pending overlay sits on top while its request is in
# flight, and every cache ingress applies it.
#
# Every message-list render runs through here, so the paths make no tuples, closures or
# comprehensions, and read rows (JavaScript objects) with `get`, a direct JavaScript call.
type KnownMessageFields = any;
type PendingOverlayMessage = any;
type ThreadUnreadTarget = any;

glob:priv listeners: any = new(globalThis.Set),
          # message id -> {read?, starred?}
          known_fields: dict[any, dict[str, any]] = {},
          # row id -> its distinct member ids, and row id -> its unread aggregate (None while
          # unknown, awaiting a trusted row); both keyed in the same order.
          thread_members: dict[any, list[any]] = {},
          thread_unread: dict[any, any] = {},
          # owner -> (message id -> fields), and owner -> (row id -> absolute unread target),
          # oldest operation first; both keyed in the same order.
          layer_messages: dict[any, dict[any, dict[str, any]]] = {},
          layer_threads: dict[any, dict[any, any]] = {};

# `o.k` of a JavaScript object: every record here comes from JavaScript callers.
def:priv get(o: any, k: str) -> any {
    return globalThis.Reflect.get(o, k);
}

# JavaScript's `xs?.length` of an array or nothing.
def:priv size(xs: any) -> int {
    return 0 if nil(xs) else len(xs);
}

# JavaScript's `x === 0`.
def:priv is_zero(x: any) -> bool {
    return bool(globalThis.Object.is(x, 0)) or bool(globalThis.Object.is(x, -0));
}

def:priv clamp(value: any, size: int) -> any {
    if not globalThis.Number.isFinite(value) {
        return 0;
    }
    return globalThis.Math.min(size, globalThis.Math.max(0, globalThis.Math.trunc(value)));
}

def:priv touches(members: list[any], ids: any) -> bool {
    for id in members {
        if id in ids {
            return True;
        }
    }
    return False;
}

def:priv id_set(ids: any) -> dict[any, bool] {
    out: dict[any, bool] = {};
    for id in ids {
        out[id] = True;
    }
    return out;
}

def:priv notify {
    for listener in globalThis.Array.from(listeners) {
        listener();
    }
}

def:priv remember_one(id: any, read: any, starred: any) {
    current = known_fields.get(id);
    if current is None {
        current = {};
        known_fields[id] = current;
    }
    if read is not None {
        current["read"] = read;
    }
    if starred is not None {
        current["starred"] = starred;
    }
}

def rememberMessageFields(messageIds: any, patch: any) {
    read = get(patch, "read");
    starred = get(patch, "starred");
    if read is None and starred is None {
        return;
    }
    for id in messageIds {
        remember_one(id, read, starred);
    }
}

# Drops optimistic member state when a rollback has no trusted snapshot.
def forgetMessageFields(messageIds: any, fields: any) {
    for id in messageIds {
        current = known_fields.get(id);
        if current is None {
            continue;
        }
        if globalThis.Boolean(get(fields, "read")) {
            current.pop("read", None);
        }
        if globalThis.Boolean(get(fields, "starred")) {
            current.pop("starred", None);
        }
        if current.get("read") is None and current.get("starred") is None {
            known_fields.pop(id);
        }
    }
}

def:priv remember_rows(rows: any) {
    for row in rows {
        id = get(row, "id");
        members = get(row, "threadMessageIds");
        grouped = size(members) > 0;
        # A grouped row's read flag is an aggregate, not the anchor's own state.
        read = None if grouped else get(row, "read");
        starred = get(row, "starred");
        if read is not None or starred is not None {
            remember_one(id, read, starred);
        }
        if grouped {
            ids: list[any] = [];
            seen: dict[any, bool] = {};
            for member in members {
                if member not in seen {
                    seen[member] = True;
                    ids.append(member);
                }
            }
            unread = get(row, "threadUnread");
            thread_members[id] = ids;
            thread_unread[id] = clamp(either(unread, 0), len(ids));
        }
    }
}

# Any action touching a member of a known conversation joins one lock group.
def getConversationLockKeys(ids: any) -> list[any] {
    keys = id_set(ids);
    for rowId in thread_members {
        members = thread_members[rowId];
        if rowId not in keys and not touches(members, keys) {
            continue;
        }
        keys[rowId] = True;
        for id in members {
            keys[id] = True;
        }
    }
    return list(keys.keys());
}

# Grouped rows containing any of these message ids.
def getThreadRowIdsForMessages(ids: any) -> list[any] {
    wanted = id_set(ids);
    rowIds: list[any] = [];
    if len(wanted) == 0 {
        return rowIds;
    }
    for rowId in thread_members {
        if touches(thread_members[rowId], wanted) {
            rowIds.append(rowId);
        }
    }
    return rowIds;
}

# Persists a server-confirmed aggregate even when its list row is not cached.
def rememberThreadUnreadTargets(targets: any) {
    for rowId in targets {
        unread = targets.get(rowId);
        if rowId in thread_members and globalThis.Number.isFinite(unread) {
            thread_unread[rowId] = clamp(unread, len(thread_members[rowId]));
        }
    }
}

# Keeps conversation membership for locking but drops an untrusted aggregate.
def invalidateThreadUnreadTargets(rowIds: any) {
    for rowId in rowIds {
        if rowId in thread_members {
            thread_unread[rowId] = None;
        }
    }
}

# The read flag on screen: the known one under every pending operation's.
def:priv visible_read(id: any) -> any {
    known = known_fields.get(id);
    read = None if known is None else known.get("read");
    for messages in layer_messages.values() {
        pending = messages.get(id);
        if pending is not None and pending.get("read") is not None {
            read = pending["read"];
        }
    }
    return read;
}

# Whether any active operation names this row: a row none names comes back as itself.
def:priv pending_for(id: any) -> bool {
    for messages in layer_messages.values() {
        if id in messages {
            return True;
        }
    }
    for threads in layer_threads.values() {
        if id in threads {
            return True;
        }
    }
    return False;
}

def:priv pending_thread_unread(rowId: any) -> any {
    unread: any = None;
    for threads in layer_threads.values() {
        target = threads.get(rowId);
        if target is not None {
            unread = target;
        }
    }
    return unread;
}

def:priv as_map(pairs: list[any]) -> any {
    return new(globalThis.Map, pairs);
}

def:priv pending_thread_targets(owner: any) -> list[any] {
    pairs: list[any] = [];
    threads = layer_threads.get(owner);
    if threads is not None {
        for rowId in threads {
            pairs.append([rowId, threads[rowId]]);
        }
    }
    return pairs;
}

def:priv thread_unread_pairs(ids: any) -> list[any] {
    wanted = id_set(ids);
    pairs: list[any] = [];
    for rowId in thread_members {
        members = thread_members[rowId];
        if not touches(members, wanted) {
            continue;
        }
        visible = getKnownThreadUnread(rowId);
        if visible is not None {
            pairs.append([rowId, clamp(visible, len(members))]);
        }
    }
    return pairs;
}

def:priv message_field_pairs(ids: any) -> list[any] {
    pairs: list[any] = [];
    for id in id_set(ids) {
        fields = getVisibleMessageFields(id);
        if fields.get("read") is not None or fields.get("starred") is not None {
            pairs.append([id, fields]);
        }
    }
    return pairs;
}

# A `def`'s result reaches JavaScript with every Map made a plain object, so these return real Maps.
glob getPendingThreadTargets: any = lambda (owner: any) -> any {
         as_map(pending_thread_targets(owner))
     },
     # Pre-click grouped unread aggregates for rollback after a failed undo.
     captureThreadUnread: any = lambda (ids: any) -> any { as_map(thread_unread_pairs(ids)) },
     # Copies only fields this tab has actually observed; unknown ids stay unknown.
     captureMessageFields: any = lambda (ids: any) -> any { as_map(message_field_pairs(ids)) };

# Latest known value including any active pending operation.
def getVisibleMessageFields(messageId: any) -> dict[str, any] {
    fields: dict[str, any] = {};
    known = known_fields.get(messageId);
    if known is not None {
        fields.update(known);
    }
    for messages in layer_messages.values() {
        pending = messages.get(messageId);
        if pending is None {
            continue;
        }
        if pending.get("read") is not None {
            fields["read"] = pending["read"];
        }
        if pending.get("starred") is not None {
            fields["starred"] = pending["starred"];
        }
    }
    return fields;
}

# The newest owner's target wins over the known aggregate.
def getKnownThreadUnread(rowId: any) -> any {
    pending = pending_thread_unread(rowId);
    if pending is not None {
        return pending;
    }
    return thread_unread.get(rowId);
}

# Applies every active owner's overlay; later owners win field by field. A row no overlay changed
# comes back as itself.
def:priv apply_pending(message: any) -> any {
    if len(layer_messages) == 0 {
        if nil(message) {
            # Reading a property of a missing message throws, as it does in JavaScript.
            get(message, "read");
        }
        return message;
    }
    id = get(message, "id");
    if not pending_for(id) {
        return message;
    }
    read0 = get(message, "read");
    starred0 = get(message, "starred");
    unread0 = get(message, "threadUnread");
    read = read0;
    starred = starred0;
    threadUnread = unread0;
    changed = False;
    for messages in layer_messages.values() {
        fields = messages.get(id);
        if fields is None {
            continue;
        }
        r = fields.get("read");
        if r is not None and read is not r {
            read = r;
            changed = True;
        }
        s = fields.get("starred");
        if s is not None and starred is not s {
            starred = s;
            changed = True;
        }
    }
    members = get(message, "threadMessageIds");
    n = size(members);
    for threads in layer_threads.values() {
        target = threads.get(id);
        if target is not None and n > 0 {
            nextUnread = clamp(target, n);
            if threadUnread is not nextUnread {
                threadUnread = nextUnread;
                changed = True;
            }
        }
    }
    if not changed {
        return message;
    }
    out: any = globalThis.Object.assign(globalThis.Object(), message);
    if read0 is not None or read is not None {
        globalThis.Reflect.set(out, "read", read);
    }
    if starred0 is not None or starred is not None {
        globalThis.Reflect.set(out, "starred", starred);
    }
    if threadUnread is not None {
        globalThis.Reflect.set(out, "threadUnread", threadUnread);
        if n > 0 {
            globalThis.Reflect.set(out, "read", is_zero(threadUnread));
        }
    }
    return out;
}

def:priv apply_pending_rows(messages: any) -> any {
    changed = False;
    out: list[any] = [];
    for message in messages {
        applied = apply_pending(message);
        if applied is not message {
            changed = True;
        }
        out.append(applied);
    }
    return out if changed else messages;
}

def:priv apply_pending_list(response: any) -> any {
    rows = get(response, "messages");
    if size(rows) == 0 {
        return response;
    }
    messages = apply_pending_rows(rows);
    if messages is rows {
        return response;
    }
    out: any = globalThis.Object.assign(globalThis.Object(), response);
    globalThis.Reflect.set(out, "messages", messages);
    return out;
}

def setPendingOverlay(owner: any, entries: any) {
    if not owner {
        return;
    }
    messages: dict[any, dict[str, any]] = {};
    for item in either(get(entries, "messages"), []) {
        read = get(item, "read");
        starred = get(item, "starred");
        if read is None and starred is None {
            continue;
        }
        id = get(item, "id");
        fields = messages.get(id);
        if fields is None {
            fields = {};
            messages[id] = fields;
        }
        if read is not None {
            fields["read"] = read;
        }
        if starred is not None {
            fields["starred"] = starred;
        }
    }
    threads: dict[any, any] = {};
    for item in either(get(entries, "threads"), []) {
        unread = get(item, "threadUnread");
        if globalThis.Number.isFinite(unread) {
            threads[get(item, "id")] = globalThis.Math.max(0, globalThis.Math.trunc(unread));
        }
    }
    if len(messages) == 0 and len(threads) == 0 {
        clearPendingOverlay(owner);
        return;
    }
    # An existing owner keeps its position, so a newer operation stays last.
    layer_messages[owner] = messages;
    layer_threads[owner] = threads;
    notify();
}

def clearPendingOverlay(owner: any) -> bool {
    if owner not in layer_messages {
        return False;
    }
    layer_messages.pop(owner);
    layer_threads.pop(owner);
    notify();
    return True;
}

def hasPendingOverlay -> bool {
    return len(layer_messages) > 0;
}

def getPendingOverlayOwners -> list[any] {
    return list(layer_messages.keys());
}

def subscribePendingOverlay(listener: any) -> any {
    listeners.add(listener);
    return lambda -> any { listeners.delete(listener) };
}

# Absolute unread targets: only real member transitions, bounded by the aggregate.
def getThreadUnreadTargets(fields: any) -> list[any] {
    reads: dict[any, any] = {};
    for field in fields {
        read = get(field, "read");
        if read is not None {
            reads[get(field, "id")] = read;
        }
    }
    targets: list[any] = [];
    if len(reads) == 0 {
        return targets;
    }
    for rowId in thread_members {
        members = thread_members[rowId];
        if not touches(members, reads) {
            continue;
        }
        visibleAggregate = getKnownThreadUnread(rowId);
        if visibleAggregate is None {
            continue;
        }
        n = len(members);
        currentUnread: int = clamp(visibleAggregate, n);
        directToRead = 0;
        directToUnread = 0;
        unknownUnread = 0;
        unknownRead = 0;
        knownUnread = 0;
        knownRead = 0;
        for id in members {
            visible = visible_read(id);
            if visible is False {
                knownUnread += 1;
            }
            if visible is True {
                knownRead += 1;
            }
            if id not in reads {
                continue;
            }
            desired = reads[id];
            if visible is None {
                if globalThis.Boolean(desired) {
                    unknownUnread += 1;
                } else {
                    unknownRead += 1;
                }
            } elif visible is not desired {
                if globalThis.Boolean(desired) {
                    directToRead += 1;
                } else {
                    directToUnread += 1;
                }
            }
        }
        unknownUnreadAvailable = max(0, currentUnread - knownUnread);
        unknownReadAvailable = max(0, n - currentUnread - knownRead);
        toRead = directToRead + min(unknownUnread, unknownUnreadAvailable);
        toUnread = directToUnread + min(unknownRead, unknownReadAvailable);
        target: any = globalThis.Object();
        globalThis.Reflect.set(target, "id", rowId);
        globalThis.Reflect.set(target, "threadUnread", clamp(currentUnread - toRead + toUnread, n));
        targets.append(target);
    }
    return targets;
}

def clearKnownMessageFieldsForTests {
    known_fields.clear();
    thread_members.clear();
    thread_unread.clear();
    layer_messages.clear();
    layer_threads.clear();
}

# The entry points of every list render, as function values: JavaScript calls them as they are,
# without a `def`'s conversion of each argument and result at the boundary.
glob applyPendingToMessage: any = lambda (message: any) -> any { apply_pending(message) },
     applyPendingToMessages: any = lambda (messages: any) -> any { apply_pending_rows(messages) },
     applyPendingToMessageList: any = lambda (response: any) -> any {
         apply_pending_list(response)
     },
     rememberMessageRows: any = lambda (rows: any) -> any { remember_rows(rows) };
