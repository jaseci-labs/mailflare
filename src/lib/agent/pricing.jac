def parseAgentModelRates(value: any) -> any {
    rate = lambda (v: any) -> any { v if globalThis.Number.isFinite(v) and v >= 0 else NULL };
    try {
        p = globalThis.JSON.parse(value) if value else NULL;
        # fromEntries keeps a model named "__proto__" as an own key.
        rows = [e for e in entries(p) if is_object(e[1]) and not globalThis.Array.isArray(e[1])];
        rows = [[m, record({k: rate(r[k]) for k in ["input", "output"]})] for (m, r) in rows];
        return {} if globalThis.Array.isArray(p) else globalThis.Object.fromEntries(rows);
    } except Exception {
        return {};
    }
}

def calculateAgentCostUsdMicros(usage: any, r: any) -> any {
    bad = not r or r["input"] is NULL or r["output"] is NULL;
    (i, o) = (None, None) if bad else (usage["inputTokens"], usage["outputTokens"]);
    (N, rnd) = (globalThis.Number, globalThis.Math.round);
    return NULL if i is None or o is None else rnd(N(i) * N(r["input"]) + N(o) * N(r["output"]));
}
