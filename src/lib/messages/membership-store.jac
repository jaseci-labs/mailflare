type MembershipPatch = any;
type KnownMembershipRow = any;
type RestoredRow = any;

# Every message-list render runs through here, so the paths make no tuples, closures or
# comprehensions; rows are JavaScript objects, read with `get` (a direct JavaScript call) and
# copied with `spread`.

glob:priv TOMBSTONE_TTL_MS: int = 2 * 60000,
          TOMBSTONE_LIMIT: int = 200,
          KNOWN_ROW_LIMIT: int = 5000,
          GROUPED_MEMBER_LIMIT: int = 10000,
          listeners: any = new(globalThis.Set),
          grouped_members: dict[any, bool] = {},
          restored_ids: set[any] = set(),
          # message id -> its compact row (a grouped member shares its representative's)
          known_rows: dict[any, any] = {},
          # owner -> (message id -> membership patch), oldest operation first
          pending_layers: dict[any, dict[any, dict[str, any]]] = {},
          # removed rows: {key, row, removedIds, index, offset, expiresAt}
          tombstones: list[dict[str, any]] = [];

# `o.k` of a JavaScript object or a Jac dict.
def:priv get(o: any, k: str) -> any {
    return o.get(k) if isinstance(o, dict) else globalThis.Reflect.get(o, k);
}

# JavaScript's `xs?.length` of an array or nothing.
def:priv size(xs: any) -> int {
    return 0 if nil(xs) else len(xs);
}

# `{...a, ...b}` of JavaScript objects (a Jac dict `b` gives its entries).
def:priv spread(a: any, b: any) -> any {
    return globalThis.Object.assign(globalThis.Object(), a, b);
}

# JavaScript's `xs?.includes(x)` of an array of ids.
def:priv includes(xs: any, x: any) -> bool {
    if nil(xs) {
        return False;
    }
    for y in xs {
        if y is x {
            return True;
        }
    }
    return False;
}

# `[...new Set(items)]`.
def:priv unique(items: any) -> list[any] {
    seen: dict[any, bool] = {};
    out: list[any] = [];
    for item in items {
        if item not in seen {
            seen[item] = True;
            out.append(item);
        }
    }
    return out;
}

def:priv notify {
    for listener in globalThis.Array.from(listeners) {
        listener();
    }
}

def:priv fields_of(row: any) -> dict[str, any] {
    return {
        "status": get(row, "status"),
        "folderId": either(get(row, "folderId"), NULL),
        "snoozedUntil": either(get(row, "snoozedUntil"), NULL),
        "starred": get(row, "starred"),
    };
}

def:priv compact_row(row: any) -> any {
    members = get(row, "threadMessageIds");
    copy: any = None;
    if not nil(members) {
        copy = [];
        for id in members {
            copy.append(id);
        }
    }
    return globalThis.Object({
        "id": get(row, "id"),
        "mailboxId": get(row, "mailboxId"),
        "direction": get(row, "direction"),
        "status": get(row, "status"),
        "read": get(row, "read"),
        "starred": get(row, "starred"),
        "folderId": either(get(row, "folderId"), NULL),
        "snoozedUntil": either(get(row, "snoozedUntil"), NULL),
        "threadId": get(row, "threadId"),
        "threadMessageIds": copy,
    });
}

# Only a grouped row identifies the whole conversation: an ungrouped list can hold several
# messages of one thread, each with its own row.
def:priv row_identity(row: any) -> str {
    thread = get(row, "threadId");
    if size(get(row, "threadMessageIds")) > 0 and globalThis.Boolean(thread) {
        return globalThis.String.prototype.concat.call("thread:", thread);
    }
    return globalThis.String.prototype.concat.call("id:", get(row, "id"));
}

def:priv holds(row: any, id: any) -> bool {
    return get(row, "id") is id or includes(get(row, "threadMessageIds"), id);
}

def:priv cap_insertion_ordered(known: any, limit: int) {
    excess = len(known) - limit;
    if excess <= 0 {
        return;
    }
    oldest: list[any] = [];
    for k in known {
        if len(oldest) >= excess {
            break;
        }
        oldest.append(k);
    }
    for k in oldest {
        known.pop(k);
    }
}

# List and thread ingress keep the fields an optimistic target needs.
def rememberMembershipRows(rows: any) {
    for row in rows {
        compact = compact_row(row);
        id = get(row, "id");
        known_rows.pop(id, None);
        known_rows[id] = compact;
        members = get(row, "threadMessageIds");
        if size(members) > 0 {
            grouped_members[id] = True;
            for member in members {
                if member not in known_rows {
                    known_rows[member] = compact;
                }
                grouped_members[member] = True;
            }
        }
    }
    cap_insertion_ordered(known_rows, KNOWN_ROW_LIMIT);
    cap_insertion_ordered(grouped_members, GROUPED_MEMBER_LIMIT);
}

def getKnownMembershipRow(id: any) -> any {
    return known_rows.get(id);
}

# A grouped member only exposes its representative's direction.
def isGroupedMember(id: any) -> bool {
    return id in grouped_members;
}

def setMembershipOverlay(owner: any, entries: any) {
    if not owner {
        return;
    }
    layer: dict[any, dict[str, any]] = {};
    for item in entries {
        patch: dict[str, any] = {};
        status = get(item, "status");
        if status is not None {
            patch["status"] = status;
        }
        folderId = get(item, "folderId");
        if folderId is not None {
            patch["folderId"] = folderId;
        }
        snoozedUntil = get(item, "snoozedUntil");
        if snoozedUntil is not None {
            patch["snoozedUntil"] = snoozedUntil;
        }
        starred = get(item, "starred");
        if starred is not None {
            patch["starred"] = starred;
        }
        if len(patch) > 0 {
            layer[get(item, "id")] = patch;
        }
    }
    if len(layer) == 0 {
        clearMembershipOverlay(owner);
        return;
    }
    # An existing owner keeps its position, so a newer operation stays last.
    pending_layers[owner] = layer;
    notify();
}

def clearMembershipOverlay(owner: any) -> bool {
    if owner not in pending_layers {
        return False;
    }
    pending_layers.pop(owner);
    notify();
    return True;
}

def hasMembershipOverlay -> bool {
    return len(pending_layers) > 0;
}

def subscribeMembership(listener: any) -> any {
    listeners.add(listener);
    return lambda -> any { listeners.delete(listener) };
}

# Latest membership patch for an id across every active operation.
def getVisibleMembership(id: any) -> dict[str, any] {
    patch: dict[str, any] = {};
    for layer in pending_layers.values() {
        item = layer.get(id);
        if item is not None {
            patch.update(item);
        }
    }
    return patch;
}

def:priv visible_membership_pairs(ids: any) -> list[any] {
    pairs: list[any] = [];
    for id in unique(ids) {
        known: any = None;
        for t in tombstones {
            if holds(t["row"], id) {
                known = t["row"];
                break;
            }
        }
        if known is None {
            known = known_rows.get(id);
        }
        if not known {
            continue;
        }
        fields = fields_of(known);
        fields.update(getVisibleMembership(id));
        pairs.append([id, fields]);
    }
    return pairs;
}

# The state on screen before an undo starts; a tombstone wins, as the committed apply updates it
# with the server's state. A function value: a `def` would hand JavaScript a plain object, not a Map.
glob captureVisibleMembership: any = lambda (ids: any) -> any {
    new(globalThis.Map, visible_membership_pairs(ids))
};

def rememberRemovedRow(
    key: any, row: any, removedIds: any, index: any, offset: any, now: any = None
) {
    if not key or len(removedIds) == 0 {
        return;
    }
    time = globalThis.Date.now() if now is None else now;
    prune_tombstones(time);
    identity = row_identity(row);
    existing: any = None;
    for t in tombstones {
        if t["key"] is key and row_identity(t["row"]) is identity {
            existing = t;
            break;
        }
    }
    expires = time + TOMBSTONE_TTL_MS;
    if existing is None {
        tombstones.append({
            "key": key,
            "row": row,
            "removedIds": unique(removedIds),
            "index": index,
            "offset": offset,
            "expiresAt": expires,
        });
        if len(tombstones) > TOMBSTONE_LIMIT {
            tombstones = tombstones[-TOMBSTONE_LIMIT:];
        }
        return;
    }
    # A conversation loses one member at a time: keep every captured member so undoing the first
    # removal still finds it after the second.
    previous = existing["row"];
    previousMembers = get(previous, "threadMessageIds");
    nextMembers = get(row, "threadMessageIds");
    if size(previousMembers) > 0 or size(nextMembers) > 0 {
        members: list[any] = unique(either(previousMembers, []));
        for id in either(nextMembers, []) {
            if id not in members {
                members.append(id);
            }
        }
        count = globalThis.Math.max(
            either(get(previous, "threadCount"), 0),
            either(get(row, "threadCount"), 0),
            len(members),
        );
        existing["row"] = spread(row, {"threadMessageIds": members, "threadCount": count});
    } else {
        existing["row"] = row;
    }
    removed = unique(existing["removedIds"]);
    for id in removedIds {
        if id not in removed {
            removed.append(id);
        }
    }
    existing["removedIds"] = removed;
    existing["index"] = globalThis.Math.min(existing["index"], index);
    existing["offset"] = offset;
    existing["expiresAt"] = expires;
}

# Committed states replace the optimistic target stored with a tombstone.
def updateRemovedRows(states: any) {
    for state in states {
        id = get(state, "id");
        fields = globalThis.Object({
            "status": get(state, "status"),
            "folderId": get(state, "folderId"),
            "snoozedUntil": get(state, "snoozedUntil"),
            "starred": get(state, "starred"),
        });
        for t in tombstones {
            if holds(t["row"], id) {
                t["row"] = spread(t["row"], fields);
            }
        }
        known = known_rows.get(id);
        if known {
            known_rows[id] = spread(known, fields);
        }
    }
}

def markRemovedRowsRestored(ids: any) {
    for id in ids {
        restored_ids.add(id);
    }
}

# Whether an id has a tombstone that an optimistic restore could bring back.
def hasRemovedRow(id: any) -> bool {
    for t in tombstones {
        if holds(t["row"], id) {
            return True;
        }
    }
    return False;
}

def clearRestoredRows(ids: any) {
    for id in ids {
        restored_ids.discard(id);
    }
}

def forgetRemovedRows(ids: any) {
    settled: dict[any, bool] = {};
    for id in ids {
        settled[id] = True;
        restored_ids.discard(id);
    }
    kept: list[dict[str, any]] = [];
    for t in tombstones {
        removed: list[any] = [];
        for id in t["removedIds"] {
            if id not in settled {
                removed.append(id);
            }
        }
        if len(removed) > 0 {
            t["removedIds"] = removed;
            kept.append(t);
        }
    }
    tombstones = kept;
}

# JavaScript's `left.index - right.index`, the restored rows' order.
def:priv by_index(left: any, right: any) -> float {
    a: float = globalThis.Number(get(left, "index"));
    b: float = globalThis.Number(get(right, "index"));
    return a - b;
}

# Rows whose undo is in flight, ready to merge into any list view.
def getRestoredRowsForList(key: any, now: any = None, offset: any = None) -> list[any] {
    prune_tombstones(globalThis.Date.now() if now is None else now);
    result: list[any] = [];
    for t in tombstones {
        # A row belongs to the page it was removed from: on another it would paint at the wrong
        # place until the refetch.
        if t["key"] is not key or (offset is not None and t["offset"] is not offset) {
            continue;
        }
        removed: list[any] = t["removedIds"];
        eligible: list[any] = [];
        for id in removed {
            if id in restored_ids {
                eligible.append(id);
            }
        }
        if len(eligible) == 0 {
            continue;
        }
        row = t["row"];
        members = get(row, "threadMessageIds");
        if size(members) > 0 {
            keep: list[any] = [];
            for id in members {
                if id not in removed or id in restored_ids {
                    keep.append(id);
                }
            }
            if len(keep) == 0 {
                continue;
            }
            row = spread(row, {"threadMessageIds": keep, "threadCount": len(keep)});
            members = keep;
        } elif get(row, "id") not in restored_ids {
            continue;
        }
        # The tombstone carries the committed state; the undo overlay of the row, else of its first
        # member that has one, restores only the fields that action changed.
        patch = getVisibleMembership(get(row, "id"));
        if not nil(members) {
            for id in members {
                if len(patch) > 0 {
                    break;
                }
                patch = getVisibleMembership(id);
            }
        }
        if len(patch) > 0 {
            row = spread(row, patch);
        }
        result.append(globalThis.Object({
            "row": row,
            "index": t["index"],
            "offset": t["offset"],
            "eligible": eligible,
        }));
    }
    if len(result) < 2 {
        return result;
    }
    return globalThis.Array.prototype.sort.call(result, by_index);
}

def:priv matches(row: any, patch: dict[str, any], context: any, now: any) -> bool {
    state = fields_of(row);
    state.update(patch);
    folder = get(context, "folder");
    return bool(messageMatchesFolder(state, folder, get(context, "folderId"), now));
}

def:priv filter_pending_row(row: any, context: any, now: any) -> any {
    if not context {
        return row;
    }
    members = get(row, "threadMessageIds");
    if size(members) == 0 {
        patch = getVisibleMembership(get(row, "id"));
        if len(patch) == 0 {
            return row;
        }
        return row if matches(row, patch, context, now) else NULL;
    }
    remaining: list[any] = [];
    for id in members {
        patch = getVisibleMembership(id);
        if len(patch) == 0 or matches(row, patch, context, now) {
            remaining.append(id);
        }
    }
    if len(remaining) == len(members) {
        return row;
    }
    if len(remaining) == 0 {
        return NULL;
    }
    return spread(row, {"threadMessageIds": remaining});
}

# The membership-adjusted view of a raw list response. The cache keeps the server totals, so
# repeated ingress is idempotent: hidden rows are counted from the rows present, and restored
# rows are only added when missing.
def applyMembershipToList(response: any, key: any, now: any = None) -> any {
    source = get(response, "messages");
    if not globalThis.Boolean(source) {
        return response;
    }
    time = globalThis.Date.now() if now is None else now;
    context = getListMembershipContext(key);
    messages: list[any] = [];
    hidden = 0;
    changed = False;
    for row in source {
        filtered = filter_pending_row(row, context, time);
        if filtered is not row {
            changed = True;
        }
        if filtered {
            messages.append(filtered);
        } else {
            hidden += 1;
        }
    }
    offset = either(get(response, "offset"), 0);
    restored = getRestoredRowsForList(getListMembershipKey(key), time, offset);
    added = 0;
    membersAdded = 0;
    for r in restored {
        restoredRow = get(r, "row");
        identity = row_identity(restoredRow);
        at = -1;
        for i in range(len(messages)) {
            if row_identity(messages[i]) is identity {
                at = i;
                break;
            }
        }
        if at < 0 {
            spot: float = globalThis.Math.min(
                globalThis.Math.max(0, get(r, "index")), len(messages)
            );
            messages.insert(0 if globalThis.Number.isNaN(spot) else int(spot), restoredRow);
            added += 1;
            continue;
        }
        current = messages[at];
        have = get(current, "threadMessageIds");
        if size(have) == 0 {
            continue;
        }
        missing: list[any] = [];
        for id in get(r, "eligible") {
            if not includes(have, id) {
                missing.append(id);
            }
        }
        if len(missing) == 0 {
            continue;
        }
        joined: list[any] = [];
        for id in have {
            joined.append(id);
        }
        joined.extend(missing);
        count = either(get(current, "threadCount"), len(have)) + len(missing);
        messages[at] = spread(current, {"threadMessageIds": joined, "threadCount": count});
        membersAdded += len(missing);
    }
    if hidden == 0 and added == 0 and membersAdded == 0 and not changed {
        return response;
    }
    total: float = globalThis.Number(either(get(response, "total"), len(source)));
    return spread(
        response,
        {"messages": messages, "total": globalThis.Math.max(0, total - hidden + added)},
    );
}

def:priv prune_tombstones(now: any) {
    live: list[dict[str, any]] = [];
    for t in tombstones {
        if t["expiresAt"] > now {
            live.append(t);
        }
    }
    tombstones = live;
}

# Test and session reset.
def clearMembershipState {
    known_rows.clear();
    grouped_members.clear();
    pending_layers.clear();
    tombstones = [];
    restored_ids.clear();
    notify();
}

def clearMembershipForTests {
    clearMembershipState();
    listeners.clear();
}
