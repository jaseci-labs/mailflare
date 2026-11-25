glob:priv MISSING: any = rx(
    r"""no such table:\s*users|relation "users" does not exist|table '[^']*\.?users' doesn't exist""",
    "i",
);

def isMissingUsersTableError(error: any) -> bool {
    (cur, chain) = (error, []);
    while cur and cur not in chain {
        chain.append(cur);
        cur = cur["cause"] if is_object(cur) and globalThis.Reflect.has(cur, "cause") else None;
    }
    return any([isinstance(c, globalThis.Error) and MISSING.test(c.message) for c in chain]);
}
