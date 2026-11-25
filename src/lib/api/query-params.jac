glob:priv N: any = globalThis.Number;

"""Page size: a positive integer capped at `max`, else `fallback`. Junk must never reach `.limit()`:
SQLite treats `LIMIT -1` as no limit and other databases reject it."""
def parseLimit(value: any, fallback: any, max: any) -> any {
    n = N(value);
    ok = value is not NULL and N.isInteger(n) and n >= 1;
    return globalThis.Math.min(n, max) if ok else fallback;
}

"""Row offset: a non-negative integer, 0 when missing or junk."""
def parseOffset(value: any = None) -> any {
    n = N(either(value, 0));
    return n if N.isInteger(n) and n > 0 else 0;
}
