"""What Jac needs to speak JavaScript's dialect: its null, its regular expressions."""

# JavaScript's null. Jac's None is undefined, and `??` and `is None` do not see null.
glob NULL: any = globalThis.JSON.parse("null");

"""True of undefined and of null."""
def nil(v: any) -> bool {
    return v is None or v is NULL;
}

"""`v ?? fallback` as JavaScript reads it, null included."""
def either(v: any, fallback: any) -> any {
    return fallback if nil(v) else v;
}

def rx(pattern: str, flags: str = "") -> any {
    return new(globalThis.RegExp, pattern, flags);
}

"""JavaScript's `s.replace(regex, to)`: `to` is a string with `$1` groups, or a function."""
def rx_sub(s: str, regex: any, to: any) -> str {
    return globalThis.String.prototype.replace.call(s, regex, to);
}
