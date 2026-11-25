"""Pure helpers for JMAP change states; see changes.jac."""

glob:priv PREFIX = "c1";

def formatState(seq: any, fingerprint: str) -> str {
    return f"{PREFIX}:{globalThis.String(seq)}:{fingerprint}";
}

def parseState(value: any) -> any {
    if not isinstance(value, str) {
        return NULL;
    }
    parts = value.split(":");
    if len(parts) != 3 or parts[0] != PREFIX or not parts[2] {
        return NULL;
    }
    seq = globalThis.Number(parts[1]);
    return {"seq": seq, "fingerprint": parts[2]}
        if globalThis.Number.isSafeInteger(seq) and seq >= 0
        else NULL;
}

"""Folds ordered change rows into JMAP's created/updated/destroyed sets.

An object created and destroyed in the window is not reported at all, one
destroyed and created again (moved away and back) is updated.
"""
def coalesceChanges(rows: any) -> dict[str, any] {
    (created, updated, destroyed) = [new(globalThis.Set) for _ in range(3)];
    for row in rows {
        (id, change) = (row["id"], row["change"]);
        if change == "created" {
            (updated if destroyed.delete(id) else created).add(id);
        } elif change == "updated" {
            if not created.has(id) {
                updated.add(id);
            }
        } elif change == "destroyed" and not created.delete(id) {
            updated.delete(id);
            destroyed.add(id);
        }
    }
    return {
        "created": globalThis.Array.from(created),
        "updated": globalThis.Array.from(updated),
        "destroyed": globalThis.Array.from(destroyed),
    };
}
