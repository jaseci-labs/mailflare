"""What a Jac module needs to speak JavaScript's dialect: its null, its plain objects, its regular expressions."""

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

"""`o.k ?? fallback` of a record that is a Jac dict or a JavaScript object."""
def at(o: any, k: str, fallback: any = None) -> any {
    return either(o.get(k) if isinstance(o, dict) else getattr(o, k, None), fallback);
}

"""`k in o` of a Jac dict or a JavaScript object."""
def owns(o: any, k: str) -> bool {
    return k in o if isinstance(o, dict) else globalThis.Object.hasOwn(o, k);
}

def entries(o: any) -> list[any] {
    return list(o.items()) if isinstance(o, dict) else list(globalThis.Object.entries(o));
}

"""A dict as the plain JavaScript object a caller reads with `.k`."""
def record(d: any) -> any {
    return globalThis.Object(d);
}

"""`{...a, ...b}`: one JavaScript object of the parts' entries, later parts winning."""
def merged(*parts: any) -> any {
    out: any = globalThis.Object();
    for part in parts {
        for (k, v) in entries(part) {
            out[k] = v;
        }
    }
    return out;
}

def rx(pattern: str, flags: str = "") -> any {
    return new(globalThis.RegExp, pattern, flags);
}

"""JavaScript's `s.replace(regex, to)`: `to` is a string with `$1` groups, or a function."""
def rx_sub(s: str, regex: any, to: any) -> str {
    return globalThis.String.prototype.replace.call(s, regex, to);
}
