# Names the TypeScript side imports as types: a partial set of membership fields, the compact
# fields needed to derive an optimistic move target, and a row whose undo is in flight.
type MembershipPatch = any;
type KnownMembershipRow = any;
type RestoredRow = any;

glob:priv PATCH_FIELDS: list[str] = ["status", "folderId", "snoozedUntil", "starred"],
          TOMBSTONE_TTL_MS: int = 2 * 60000,
          TOMBSTONE_LIMIT: int = 200,
          KNOWN_ROW_LIMIT: int = 5000,
          GROUPED_MEMBER_LIMIT: int = 10000,
          # message id -> its compact row (a grouped member shares its representative's)
          known_rows: dict[str, any] = {},
          grouped_members: dict[str, bool] = {},
          # owner -> (message id -> membership patch), oldest operation first
          pending_layers: dict[str, dict[str, dict[str, any]]] = {},
          listeners: list[any] = [],
          # removed rows: {key, row, removedIds, index, offset, expiresAt}
          tombstones: list[dict[str, any]] = [],
          restored_ids: set[any] = set();

"""A property of a record that may lack it: undefined when missing, null kept as null."""
def:priv opt(o: any, k: str) -> any {
    return o.get(k) if isinstance(o, dict) else getattr(o, k, None);
}

def:priv members(row: any) -> list[any] {
    return either(opt(row, "threadMessageIds"), []);
}

def:priv unique(items: list[any]) -> list[any] {
    return list({item: True for item in items}.keys());
}

def:priv notify {
    for listener in list(listeners) {
        listener();
    }
}

def:priv membership_fields_of(row: any) -> dict[str, any] {
    return {
        "status": opt(row, "status"),
        "folderId": at(row, "folderId", NULL),
        "snoozedUntil": at(row, "snoozedUntil", NULL),
        "starred": opt(row, "starred"),
    };
}

def:priv compact_row(row: any) -> any {
    ids = opt(row, "threadMessageIds");
    return merged(
        {k: opt(row, k) for k in ["id", "mailboxId", "direction", "status", "read", "starred"]},
        {
            "folderId": at(row, "folderId", NULL),
            "snoozedUntil": at(row, "snoozedUntil", NULL),
            "threadId": opt(row, "threadId"),
            "threadMessageIds": None if nil(ids) else list(ids),
        },
    );
}

"""
Only a grouped row identifies the whole conversation. An ungrouped list
can contain several messages from one thread, each with its own row.
"""
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

"""List and thread ingress keep the fields an optimistic target needs."""
def rememberMembershipRows(rows: any) {
    for row in rows {
        compact = compact_row(row);
        known_rows.pop(row["id"], None);
        known_rows[row["id"]] = compact;
        if members(row) {
            grouped_members[row["id"]] = True;
            for id in members(row) {
                known_rows.setdefault(id, compact);
                grouped_members[id] = True;
            }
        }
    }
    cap_insertion_ordered(known_rows, KNOWN_ROW_LIMIT);
    cap_insertion_ordered(grouped_members, GROUPED_MEMBER_LIMIT);
}

def getKnownMembershipRow(id: str) -> any {
    return known_rows.get(id);
}

"""A grouped member only exposes its representative's direction."""
def isGroupedMember(id: str) -> bool {
    return id in grouped_members;
}

def setMembershipOverlay(owner: str, entries: any) {
    if not owner {
        return;
    }
    layer: dict[str, dict[str, any]] = {};
    for item in entries {
        patch = {k: opt(item, k) for k in PATCH_FIELDS if opt(item, k) is not None};
        if patch {
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
    if listener not in listeners {
        listeners.append(listener);
    }
    def unsubscribe -> bool {
        if listener not in listeners {
            return False;
        }
        listeners.remove(listener);
        return True;
    }
    return unsubscribe;
}

"""Latest membership patch for an id across every active operation."""
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
        buried = [item["row"] for item in tombstones if holds(item["row"], id)];
        known = buried[0] if buried else known_rows.get(id);
        if known {
            captured[id] = merged(membership_fields_of(known), getVisibleMembership(id));
        }
    }
    return captured;
}

# The state on screen before an undo starts. Prefer a tombstone because the committed apply
# updates it with the server's applied state. (A function value, not a `def`: what a `def`
# returns reaches JavaScript with a Map turned into a plain object, and callers need the Map.)
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
    identity = row_identity(row);
    existing = [
        item
        for item in tombstones
        if item["key"] == key and row_identity(item["row"]) == identity
    ];
    if not existing {
        tombstones.append({
            "key": key,
            "row": row,
            "removedIds": unique(removedIds),
            "index": index,
            "offset": offset,
            "expiresAt": time + TOMBSTONE_TTL_MS,
        });
        tombstones = tombstones[-TOMBSTONE_LIMIT:];
        return;
    }
    # A conversation loses one member at a time. Keep every captured member so
    # undoing the first removal can still find it after the second one.
    found = existing[0];
    everyone = unique(members(found["row"]) + members(row));
    found["row"] = merged(
        row,
        {
            "threadMessageIds": everyone,
            "threadCount": globalThis.Math.max(
                at(found["row"], "threadCount", 0), at(row, "threadCount", 0), len(everyone)
            ),
        },
    )
        if everyone
        else row;
    found["removedIds"] = unique(found["removedIds"] + list(removedIds));
    found["index"] = globalThis.Math.min(found["index"], index);
    found["offset"] = offset;
    found["expiresAt"] = time + TOMBSTONE_TTL_MS;
}

"""Committed states replace the optimistic target stored with a tombstone."""
def updateRemovedRows(states: any) {
    for state in states {
        fields = {k: opt(state, k) for k in PATCH_FIELDS};
        id = state["id"];
        for item in tombstones {
            if holds(item["row"], id) {
                item["row"] = merged(item["row"], fields);
            }
        }
        if known_rows.get(id) {
            known_rows[id] = merged(known_rows[id], fields);
        }
    }
}

def markRemovedRowsRestored(ids: any) {
    restored_ids.update(set(ids));
}

"""Whether an id has a tombstone that an optimistic restore could bring back."""
def hasRemovedRow(id: str) -> bool {
    return any([holds(item["row"], id) for item in tombstones]);
}

def clearRestoredRows(ids: any) {
    restored_ids.difference_update(set(ids));
}

def forgetRemovedRows(ids: any) {
    clearRestoredRows(ids);
    for item in tombstones {
        item["removedIds"] = [id for id in item["removedIds"] if id not in ids];
    }
    tombstones = [item for item in tombstones if item["removedIds"]];
}

"""The overlay of the row itself, else of its first member that has one."""
def:priv first_patch(ids: list[any]) -> dict[str, any] {
    for id in ids {
        patch = getVisibleMembership(id);
        if patch {
            return patch;
        }
    }
    return {};
}

"""Rows whose undo is in flight, ready to merge into any list view."""
def getRestoredRowsForList(key: str, now: any = None, offset: any = None) -> list[dict[str, any]] {
    prune_tombstones(globalThis.Date.now() if now is None else now);
    result: list[dict[str, any]] = [];
    for item in tombstones {
        # A row belongs to the page it was removed from. Merging it into a
        # different page would paint it at the wrong place until the refetch.
        if item["key"] != key or (offset is not None and item["offset"] is not offset) {
            continue;
        }
        removed = item["removedIds"];
        eligible = [id for id in removed if id in restored_ids];
        row = item["row"];
        keep = [id for id in members(row) if id not in removed or id in restored_ids];
        if not eligible or not (keep if members(row) else row["id"] in restored_ids) {
            continue;
        }
        if keep {
            row = merged(row, {"threadMessageIds": keep, "threadCount": len(keep)});
        }
        # The tombstone carries the committed applied state. The active undo
        # overlay restores only the fields that action changed.
        patch = first_patch([row["id"]] + keep);
        if patch {
            row = merged(row, patch);
        }
        result.append({
            "row": row,
            "index": item["index"],
            "offset": item["offset"],
            "eligible": eligible,
        });
    }
    return sorted(result, key=lambda (restored: dict[str, any]) -> any { restored["index"] });
}

def:priv filter_pending_row(row: any, context: any, now: any) -> any {
    if not context {
        return row;
    }
    def stays(id: str) -> bool {
        patch = getVisibleMembership(id);
        return not patch
            or messageMatchesFolder(
                {**membership_fields_of(row), **patch},
                at(context, "folder"),
                at(context, "folderId"),
                now,
            );
    }
    everyone = members(row);
    if not everyone {
        return row if stays(row["id"]) else NULL;
    }
    remaining = [id for id in everyone if stays(id)];
    if len(remaining) == len(everyone) {
        return row;
    }
    return merged(row, {"threadMessageIds": remaining}) if remaining else NULL;
}

"""Puts restored rows back into `messages`; gives how many rows and how many thread members it added."""
def:priv merge_restored_rows(
    messages: list[any], restored: list[dict[str, any]]
) -> tuple[int, int] {
    (added, members_added) = (0, 0);
    for item in restored {
        identity = row_identity(item["row"]);
        same = [i for i in range(len(messages)) if row_identity(messages[i]) == identity];
        if not same {
            messages.insert(min(max(0, item["index"]), len(messages)), item["row"]);
            added += 1;
            continue;
        }
        current = messages[same[0]];
        present = members(current);
        missing = [id for id in item["eligible"] if id not in present] if present else [];
        if missing {
            messages[same[0]] = merged(
                current,
                {
                    "threadMessageIds": present + missing,
                    "threadCount": at(current, "threadCount", len(present)) + len(missing),
                },
            );
            members_added += len(missing);
        }
    }
    return (added, members_added);
}

"""
Derives the membership-adjusted view of a raw list response. The cache keeps
the server totals, so repeated ingress is idempotent: hidden rows are counted
from the rows present, and restored rows are only added when missing.
"""
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
    changed = any([filtered[i] is not source[i] for i in range(len(source))]);
    restored = getRestoredRowsForList(getListMembershipKey(key), time, at(response, "offset", 0));
    (added, members_added) = merge_restored_rows(messages, restored);
    if not changed and added == 0 and members_added == 0 {
        return response;
    }
    return merged(
        response,
        {
            "messages": messages,
            "total": globalThis.Math.max(0, at(response, "total", len(source)) - hidden + added),
        },
    );
}

def:priv prune_tombstones(now: any) {
    tombstones = [item for item in tombstones if item["expiresAt"] > now];
}

"""Test and session reset."""
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
