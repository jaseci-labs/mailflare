type MembershipPatch = any;
type KnownMembershipRow = any;
type RestoredRow = any;

glob:priv M: any = globalThis.Math,
          PATCH_FIELDS: list[str] = "status folderId snoozedUntil starred".split(),
          # The compact fields an optimistic move target is derived from.
          COMPACT: list[str] = "id mailboxId direction status read starred folderId snoozedUntil threadId".split();

glob:priv TOMBSTONE_TTL_MS: int = 2 * 60000,
          TOMBSTONE_LIMIT: int = 200,
          KNOWN_ROW_LIMIT: int = 5000,
          GROUPED_MEMBER_LIMIT: int = 10000,
          listeners: any = new(globalThis.Set),
          grouped_members: dict[str, bool] = {},
          restored_ids: set[any] = set(),
          # message id -> its compact row (a grouped member shares its representative's)
          known_rows: dict[str, any] = {},
          # owner -> (message id -> membership patch), oldest operation first
          pending_layers: dict[str, dict[str, dict[str, any]]] = {},
          # removed rows: {key, row, removedIds, index, offset, expiresAt}
          tombstones: list[dict[str, any]] = [];

# A property that may be missing: undefined when missing, null kept as null.
def:priv opt(o: any, k: str) -> any {
    return o.get(k) if isinstance(o, dict) else getattr(o, k, None);
}

def:priv field(row: any, k: str) -> any {
    return at(row, k, NULL) if k in ["folderId", "snoozedUntil"] else opt(row, k);
}

def:priv members(row: any) -> list[any] {
    return either(opt(row, "threadMessageIds"), []);
}

def:priv unique(items: list[any]) -> list[any] {
    return list({item: True for item in items}.keys());
}

def:priv notify {
    for listener in globalThis.Array.from(listeners) {
        listener();
    }
}

def:priv fields_of(row: any) -> dict[str, any] {
    return {k: field(row, k) for k in PATCH_FIELDS};
}

def:priv compact_row(row: any) -> any {
    ids = opt(row, "threadMessageIds");
    ids = None if nil(ids) else list(ids);
    return merged({k: field(row, k) for k in COMPACT}, {"threadMessageIds": ids});
}

# Only a grouped row identifies the whole conversation: an ungrouped list can hold several
# messages of one thread, each with its own row.
def:priv row_identity(row: any) -> str {
    thread = opt(row, "threadId");
    return f"thread:{thread}" if members(row) and thread else f"id:{row['id']}";
}

def:priv holds(row: any, id: str) -> bool {
    return row["id"] is id or id in members(row);
}

def:priv cap_insertion_ordered(known: any, limit: int) {
    while len(known) > limit {
        known.pop(next(iter(known)));
    }
}

# List and thread ingress keep the fields an optimistic target needs.
def rememberMembershipRows(rows: any) {
    for row in rows {
        compact = compact_row(row);
        known_rows.pop(row["id"], None);
        known_rows[row["id"]] = compact;
        for id in ([row["id"]] + members(row) if members(row) else []) {
            known_rows.setdefault(id, compact);
            grouped_members[id] = True;
        }
    }
    cap_insertion_ordered(known_rows, KNOWN_ROW_LIMIT);
    cap_insertion_ordered(grouped_members, GROUPED_MEMBER_LIMIT);
}

def getKnownMembershipRow(id: str) -> any {
    return known_rows.get(id);
}

# A grouped member only exposes its representative's direction.
def isGroupedMember(id: str) -> bool {
    return id in grouped_members;
}

def setMembershipOverlay(owner: str, entries: any) {
    if not owner {
        return;
    }
    layer: dict[str, dict[str, any]] = {};
    for item in entries {
        if (patch := {k: opt(item, k) for k in PATCH_FIELDS if opt(item, k) is not None}) {
            layer[item["id"]] = patch;
        }
    }
    if not layer {
        clearMembershipOverlay(owner);
        return;
    }
    # An existing owner keeps its position, so a newer operation stays last.
    pending_layers[owner] = layer;
    notify();
}

def clearMembershipOverlay(owner: str) -> bool {
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
def getVisibleMembership(id: str) -> dict[str, any] {
    patch: dict[str, any] = {};
    for layer in pending_layers.values() {
        patch.update(layer.get(id, {}));
    }
    return patch;
}

def:priv visible_membership_of(ids: any) -> dict[str, any] {
    captured: dict[str, any] = {};
    for id in ids {
        known = first([t["row"] for t in tombstones if holds(t["row"], id)]) or known_rows.get(id);
        if known {
            captured[id] = merged(fields_of(known), getVisibleMembership(id));
        }
    }
    return captured;
}

# The state on screen before an undo starts; a tombstone wins, as the committed apply updates it
# with the server's state. A function value: a `def` would hand JavaScript a plain object, not a Map.
glob captureVisibleMembership: any = lambda (ids: any) -> any {
    new(globalThis.Map, [[k, v] for (k, v) in visible_membership_of(ids).items()])
};

def rememberRemovedRow(
    key: str, row: any, removedIds: any, index: any, offset: any, now: any = None
) {
    if not key or len(removedIds) == 0 {
        return;
    }
    time = globalThis.Date.now() if now is None else now;
    prune_tombstones(time);
    ident = row_identity(row);
    found = first([t for t in tombstones if t["key"] == key and row_identity(t["row"]) == ident]);
    expires = time + TOMBSTONE_TTL_MS;
    if found is None {
        stone = {"key": key, "row": row, "removedIds": unique(removedIds), "index": index};
        tombstones.append({**stone, "offset": offset, "expiresAt": expires});
        tombstones = tombstones[-TOMBSTONE_LIMIT:];
        return;
    }
    # A conversation loses one member at a time: keep every captured member so undoing the first
    # removal still finds it after the second.
    ids = unique(members(found["row"]) + members(row));
    count = M.max(at(found["row"], "threadCount", 0), at(row, "threadCount", 0), len(ids));
    found["row"] = merged(row, {"threadMessageIds": ids, "threadCount": count}) if ids else row;
    found["removedIds"] = unique(found["removedIds"] + list(removedIds));
    found["index"] = M.min(found["index"], index);
    (found["offset"], found["expiresAt"]) = (offset, expires);
}

# Committed states replace the optimistic target stored with a tombstone.
def updateRemovedRows(states: any) {
    for state in states {
        (id, fields) = (state["id"], {k: opt(state, k) for k in PATCH_FIELDS});
        for t in [t for t in tombstones if holds(t["row"], id)] {
            t["row"] = merged(t["row"], fields);
        }
        if known_rows.get(id) {
            known_rows[id] = merged(known_rows[id], fields);
        }
    }
}

def markRemovedRowsRestored(ids: any) {
    restored_ids.update(set(ids));
}

# Whether an id has a tombstone that an optimistic restore could bring back.
def hasRemovedRow(id: str) -> bool {
    return any([holds(t["row"], id) for t in tombstones]);
}

def clearRestoredRows(ids: any) {
    restored_ids.difference_update(set(ids));
}

def forgetRemovedRows(ids: any) {
    clearRestoredRows(ids);
    for t in tombstones {
        t["removedIds"] = [id for id in t["removedIds"] if id not in ids];
    }
    tombstones = [t for t in tombstones if t["removedIds"]];
}

# Rows whose undo is in flight, ready to merge into any list view.
def getRestoredRowsForList(key: str, now: any = None, offset: any = None) -> list[dict[str, any]] {
    prune_tombstones(globalThis.Date.now() if now is None else now);
    result: list[dict[str, any]] = [];
    for t in tombstones {
        # A row belongs to the page it was removed from: on another it would paint at the wrong
        # place until the refetch.
        if t["key"] != key or (offset is not None and t["offset"] is not offset) {
            continue;
        }
        (removed, row) = (t["removedIds"], t["row"]);
        eligible = [id for id in removed if id in restored_ids];
        keep = [id for id in members(row) if id not in removed or id in restored_ids];
        if not eligible or not (keep if members(row) else row["id"] in restored_ids) {
            continue;
        }
        if keep {
            row = merged(row, {"threadMessageIds": keep, "threadCount": len(keep)});
        }
        # The tombstone carries the committed state; the undo overlay of the row, else of its first
        # member that has one, restores only the fields that action changed.
        patch = first([p for id in [row["id"]] + keep if (p := getVisibleMembership(id))]);
        row = merged(row, patch) if patch else row;
        result.append({
            "row": row,
            "index": t["index"],
            "offset": t["offset"],
            "eligible": eligible,
        });
    }
    return sorted(result, key=lambda (r: dict[str, any]) -> any { r["index"] });
}

def:priv filter_pending_row(row: any, context: any, now: any) -> any {
    if not context {
        return row;
    }
    (folder, folderId, base) = (at(context, "folder"), at(context, "folderId"), fields_of(row));
    def stays(id: str) -> bool {
        p = getVisibleMembership(id);
        return not p or messageMatchesFolder({**base, **p}, folder, folderId, now);
    }
    ids = members(row);
    if not ids {
        return row if stays(row["id"]) else NULL;
    }
    kept = [id for id in ids if stays(id)];
    if len(kept) == len(ids) {
        return row;
    }
    return merged(row, {"threadMessageIds": kept}) if kept else NULL;
}

# Puts restored rows back into `messages`; gives how many rows and thread members it added.
def:priv merge_restored_rows(
    messages: list[any], restored: list[dict[str, any]]
) -> tuple[int, int] {
    (added, members_added) = (0, 0);
    for r in restored {
        ident = row_identity(r["row"]);
        same = [i for i in range(len(messages)) if row_identity(messages[i]) == ident];
        if not same {
            messages.insert(min(max(0, r["index"]), len(messages)), r["row"]);
            added += 1;
            continue;
        }
        (cur, have) = (messages[same[0]], members(messages[same[0]]));
        missing = [id for id in r["eligible"] if id not in have] if have else [];
        if missing {
            n = at(cur, "threadCount", len(have)) + len(missing);
            messages[same[0]] = merged(cur, {"threadMessageIds": have + missing, "threadCount": n});
            members_added += len(missing);
        }
    }
    return (added, members_added);
}

# The membership-adjusted view of a raw list response. The cache keeps the server totals, so
# repeated ingress is idempotent: hidden rows are counted from the rows present, and restored
# rows are only added when missing.
def applyMembershipToList(response: any, key: str, now: any = None) -> any {
    source = opt(response, "messages");
    if nil(source) {
        return response;
    }
    time = globalThis.Date.now() if now is None else now;
    context = getListMembershipContext(key);
    filtered = [filter_pending_row(row, context, time) for row in source];
    messages = [row for row in filtered if row];
    hidden = len(source) - len(messages);
    changed = any([f is not s for (f, s) in zip(filtered, source)]);
    restored = getRestoredRowsForList(getListMembershipKey(key), time, at(response, "offset", 0));
    (added, members_added) = merge_restored_rows(messages, restored);
    if not changed and added == 0 and members_added == 0 {
        return response;
    }
    total = M.max(0, at(response, "total", len(source)) - hidden + added);
    return merged(response, {"messages": messages, "total": total});
}

def:priv prune_tombstones(now: any) {
    tombstones = [t for t in tombstones if t["expiresAt"] > now];
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
