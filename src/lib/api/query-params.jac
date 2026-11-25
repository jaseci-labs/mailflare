"""Page-size query parameter: a positive integer capped at `max`, `fallback` when missing or junk.
A negative or non-numeric value must never reach `.limit()`: SQLite treats `LIMIT -1` as no limit
and other databases reject it."""
def parseLimit(value: any, fallback: any, max: any) -> any {
    if value is NULL {
        return fallback;
    }
    parsed = globalThis.Number(value);
    if not globalThis.Number.isInteger(parsed) or parsed < 1 {
        return fallback;
    }
    return globalThis.Math.min(parsed, max);
}

"""Row offset query parameter: a non-negative integer, 0 when missing or junk."""
def parseOffset(value: any = None) -> any {
    parsed = globalThis.Number(either(value, 0));
    return parsed if globalThis.Number.isInteger(parsed) and parsed > 0 else 0;
}
