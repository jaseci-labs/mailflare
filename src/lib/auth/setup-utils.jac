glob:priv MISSING: any = rx(
    r"""no such table:\s*users|relation "users" does not exist|table '[^']*\.?users' doesn't exist""",
    "i",
);

def isMissingUsersTableError(error: any) -> bool {
    (cur, seen) = (error, new(globalThis.Set));
    while cur and not seen.has(cur) {
        seen.add(cur);
        if isinstance(cur, globalThis.Error) and MISSING.test(cur.message) {
            return True;
        }
        cur = cur["cause"] if is_object(cur) and globalThis.Reflect.has(cur, "cause") else None;
    }
    return False;
}
