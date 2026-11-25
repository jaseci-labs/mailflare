"""Applies a one-shot unread delta to the folders it names. Returns the same object when nothing changes."""
def applyCountsDelta(counts: any, delta: any) -> any {
    changes = [(k, num_or(delta[f"{k}UnreadDelta"], 0)) for k in ["inbox", "promotions"]];
    f = merged(counts["folders"]);
    for (k, d) in [(k, d) for (k, d) in changes if d] {
        f[k] = merged(f[k], {"unread": globalThis.Math.max(0, f[k]["unread"] + d)});
    }
    return merged(counts, {"folders": f}) if any([d for (_, d) in changes]) else counts;
}
