def:priv is_record(v: any) -> bool {
    return globalThis.Object.prototype.toString.call(v) == "[object Object]";
}

"""A rate that is a finite number of at least zero, else null."""
def:priv rate(rates: any, k: str) -> any {
    v = rates[k];
    return v if globalThis.Number.isFinite(v) and v >= 0 else NULL;
}

"""The per-model token rates of the stored JSON setting; anything malformed is left out."""
def parseAgentModelRates(value: any) -> any {
    if not value {
        return {};
    }
    try {
        parsed = globalThis.JSON.parse(value);
    } except Exception {
        return {};
    }
    if not is_record(parsed) {
        return {};
    }
    return {
        model: {"input": rate(rates, "input"), "output": rate(rates, "output")}
        for (model, rates) in entries(parsed)
        if is_record(rates)
    };
}

def calculateAgentCostUsdMicros(usage: any, rates: any) -> any {
    if not rates
        or rates["input"] is NULL
        or rates["output"] is NULL
        or usage["inputTokens"] is None
        or usage["outputTokens"] is None
    {
        return NULL;
    }
    # Number() keeps JavaScript's arithmetic for a count or rate that is not a number.
    num = globalThis.Number;
    return globalThis.Math.round(
        num(usage["inputTokens"]) * num(rates["input"])
            + num(usage["outputTokens"]) * num(rates["output"]),
    );
}
