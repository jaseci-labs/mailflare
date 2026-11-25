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

"""JavaScript's `typeof v === "object" && v !== null`: arrays included, functions not."""
def is_object(v: any) -> bool {
    return not nil(v) and not callable(v) and globalThis.Object(v) is v;
}

"""A JavaScript integer within `lo..hi` (`Number.isInteger(v) && lo <= v && v <= hi`)."""
def whole(v: any, lo: any = None, hi: any = None) -> bool {
    return bool(globalThis.Number.isInteger(v))
        and (lo is None or v >= lo)
        and (hi is None or v <= hi);
}

"""`xs[0]`, undefined for an empty or missing array (Jac's index raises)."""
def first(xs: any) -> any {
    return xs[0] if not nil(xs) and len(xs) > 0 else None;
}

"""JavaScript's `n || fallback` of a number: 0 and NaN fall back (Jac holds NaN truthy)."""
def num_or(n: any, fallback: any) -> any {
    return fallback if not n or globalThis.Number.isNaN(n) else n;
}

"""`o?.a?.b ?? fallback` along `path`."""
def dig(o: any, path: list[str], fallback: any = None) -> any {
    for k in path {
        if nil(o) {
            return fallback;
        }
        o = at(o, k);
    }
    return either(o, fallback);
}

"""`s.replace(regex, to)` as a JavaScript string, for chaining JavaScript's own methods."""
def sub(s: any, regex: any, to: any) -> any {
    return globalThis.String.prototype.replace.call(s, regex, to);
}

"""JavaScript's in-place `xs.sort(cmp)`, which takes a comparator returning a number."""
def js_sort(xs: any, cmp: any = None) -> any {
    return globalThis.Array.prototype.sort.call(xs, cmp);
}

"""Start a coroutine as a JavaScript promise, which can be shared and awaited more than once."""
def promise(coro: any) -> any {
    return globalThis.Promise.resolve(coro);
}
