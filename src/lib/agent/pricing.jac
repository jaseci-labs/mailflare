glob:priv IO: any = ["input", "output"],
          arr: any = globalThis.Array.isArray,
          N: any = globalThis.Number,
          rnd: any = globalThis.Math.round;

def:priv rates(r: any) -> any {
    return record({k: r[k] if N.isFinite(r[k]) and r[k] >= 0 else NULL for k in IO});
}

def parseAgentModelRates(value: any) -> any {
    try {
        p = globalThis.JSON.parse(value) if value else NULL;
        # fromEntries keeps a model named "__proto__" as an own key.
        rows = [[m, rates(r)] for (m, r) in entries(p) if is_object(r) and not arr(r)];
        return {} if arr(p) else globalThis.Object.fromEntries(rows);
    } except Exception {
        return {};
    }
}

def calculateAgentCostUsdMicros(usage: any, r: any) -> any {
    bad = not r or r["input"] is NULL or r["output"] is NULL;
    (i, o) = (None, None) if bad else (usage["inputTokens"], usage["outputTokens"]);
    return NULL if i is None or o is None else rnd(N(i) * N(r["input"]) + N(o) * N(r["output"]));
}
