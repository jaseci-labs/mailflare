glob:priv MISSING_USERS: any = rx(
    r"""no such table:\s*users|relation "users" does not exist|table '[^']*\.?users' doesn't exist""",
    "i",
);

"""True when the error, or anything along its `cause` chain, says the users table is absent."""
def isMissingUsersTableError(error: any) -> bool {
    current = error;
    visited: list[any] = [];
    while current and not any(seen is current for seen in visited) {
        visited.append(current);
        if isinstance(current, globalThis.Error) and MISSING_USERS.test(current.message) {
            return True;
        }
        # Only an object can carry a cause; `in` on a primitive would throw.
        if globalThis.Object(current) is not current
            or callable(current)
            or not globalThis.Reflect.has(current, "cause")
        {
            break;
        }
        current = current["cause"];
    }
    return False;
}
