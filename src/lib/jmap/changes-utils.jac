# A state is `c1:<seq>:<access fingerprint>`; see changes.ts. Change rows are folded per row, so
# these call JavaScript's own methods through `globalThis` (a direct call) and make no tuples.
def formatState(seq: any, fingerprint: any) -> str {
    return globalThis.String.prototype.concat.call("c1:", seq, ":", fingerprint);
}

def parseState(value: any) -> any {
    if not isinstance(value, str) {
        return NULL;
    }
    first: int = globalThis.String.prototype.indexOf.call(value, ":");
    second: int = -1 if first < 0 else globalThis.String.prototype.indexOf.call(value, ":", first + 1);
    if second < 0 or globalThis.String.prototype.indexOf.call(value, ":", second + 1) >= 0 {
        return NULL;
    }
    fingerprint = globalThis.String.prototype.slice.call(value, second + 1);
    if globalThis.String.prototype.slice.call(value, 0, first) != "c1" or not fingerprint {
        return NULL;
    }
    seq = globalThis.Number(globalThis.String.prototype.slice.call(value, first + 1, second));
    if not (globalThis.Number.isSafeInteger(seq) and seq >= 0) {
        return NULL;
    }
    out: any = globalThis.Object();
    out.seq = seq;
    out.fingerprint = fingerprint;
    return out;
}

# An object created and destroyed in the window is not reported at all; one destroyed and
# created again (moved away and back) is updated.
def coalesceChanges(rows: any) -> any {
    created = new(globalThis.Set);
    updated = new(globalThis.Set);
    destroyed = new(globalThis.Set);
    for row in rows {
        id = globalThis.Reflect.get(row, "id");
        change = globalThis.Reflect.get(row, "change");
        if change == "created" {
            if globalThis.Set.prototype.delete.call(destroyed, id) {
                globalThis.Set.prototype.add.call(updated, id);
            } else {
                globalThis.Set.prototype.add.call(created, id);
            }
        } elif change == "updated" {
            if not globalThis.Set.prototype.has.call(created, id) {
                globalThis.Set.prototype.add.call(updated, id);
            }
        } elif change == "destroyed" {
            if not globalThis.Set.prototype.delete.call(created, id) {
                globalThis.Set.prototype.delete.call(updated, id);
                globalThis.Set.prototype.add.call(destroyed, id);
            }
        }
    }
    out: any = globalThis.Object();
    out.created = globalThis.Array.from(created);
    out.updated = globalThis.Array.from(updated);
    out.destroyed = globalThis.Array.from(destroyed);
    return out;
}
