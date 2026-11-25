# A state is `c1:<seq>:<access fingerprint>`; see changes.ts.
def formatState(seq: any, fingerprint: str) -> str {
    return f"c1:{globalThis.String(seq)}:{fingerprint}";
}

def parseState(value: any) -> any {
    parts = value.split(":") if isinstance(value, str) else [];
    if len(parts) != 3 or parts[0] != "c1" or not parts[2] {
        return NULL;
    }
    seq = globalThis.Number(parts[1]);
    ok = globalThis.Number.isSafeInteger(seq) and seq >= 0;
    return {"seq": seq, "fingerprint": parts[2]} if ok else NULL;
}

# An object created and destroyed in the window is not reported at all; one destroyed and
# created again (moved away and back) is updated.
def coalesceChanges(rows: any) -> dict[str, any] {
    (c, u, d) = [new(globalThis.Set) for _ in range(3)];
    for row in rows {
        (id, change) = (row["id"], row["change"]);
        if change == "created" {
            (u if d.delete(id) else c).add(id);
        } elif change == "updated" and not c.has(id) {
            u.add(id);
        } elif change == "destroyed" and not c.delete(id) {
            u.delete(id);
            d.add(id);
        }
    }
    arr = globalThis.Array.from;
    return {"created": arr(c), "updated": arr(u), "destroyed": arr(d)};
}
