"""Saved placement first (dropping ids that no longer exist or repeat), then any item the layout
has never seen goes at the end of its default list."""
def resolveLayout(defaults: any, stored: any) -> any {
    known = new(globalThis.Set, [i for (_, ids) in entries(defaults) for i in ids]);
    (seen, layout) = (new(globalThis.Set), {});
    for (k, _) in entries(defaults) {
        layout[k] = [];
        for i in either(stored[k], []) {
            if known.has(i) and not seen.has(i) {
                seen.add(i);
                layout[k].append(i);
            }
        }
    }
    for (k, ids) in entries(defaults) {
        layout[k].extend([i for i in ids if not seen.has(i)]);
    }
    return layout;
}

"""Take `id` out of whichever list holds it and insert it into `listId` before `beforeId` (end when null)."""
def moveItem(layout: any, id: any, listId: any, beforeId: any) -> any {
    nxt = {k: [i for i in ids if i != id] for (k, ids) in entries(layout)};
    target = nxt.get(listId, []);
    at = target.index(beforeId) if beforeId is not NULL and beforeId in target else len(target);
    target.insert(at, id);
    nxt[listId] = target;
    return nxt;
}

def readStorage(key: any, fallback: any) -> any {
    try {
        raw = globalThis.localStorage.getItem(key);
        return fallback if raw is NULL else globalThis.JSON.parse(raw);
    } except Exception {
        return fallback;
    }
}

def writeStorage(key: any, value: any) {
    try {
        globalThis.localStorage.setItem(key, globalThis.JSON.stringify(value));
    } except Exception {}  # Storage can be unavailable (private windows); the setting just won't persist.
}
