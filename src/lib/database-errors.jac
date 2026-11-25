"""
Whether any error in the chain matches: a driver error code (`code`/`errno`, as pg and mysql2 set
them, so wording and locale do not matter) or, failing that, a message matching `pattern`. Drizzle
wraps driver errors as "Failed query: ..." and keeps the driver error on `cause`, so checking only
the outer error misses it. The patterns cover SQLite/D1, PostgreSQL and MySQL wording.
"""
def:priv chain_matches(error: any, pattern: any, codes: list[any] = []) -> bool {
    current = error;
    visited: any = new(globalThis.Set);
    while current and not visited.has(current) {
        visited.add(current);
        # `Object(x) is x` is JavaScript's `typeof x === "object"` (or a function)
        structured = globalThis.Object(current) is current;
        if structured and [c for c in codes if c is current["code"] or c is current["errno"]] {
            return True;
        }
        text = current.message
            if isinstance(current, globalThis.Error)
            else globalThis.String(current);
        if pattern.test(text) {
            return True;
        }
        if not structured or not globalThis.Reflect.has(current, "cause") {
            break;
        }
        current = current["cause"];
    }
    return False;
}

"""The table does not exist yet, for features whose migration may not be applied."""
def isMissingTableError(error: any = None) -> bool {
    return chain_matches(
        error,
        rx(r"""no such table|relation "[^"]+" does not exist|table '[^']+' doesn't exist""", "i"),
        ["42P01", 1146, "ER_NO_SUCH_TABLE"],
    );
}

"""A column added by a migration that may not be applied yet."""
def isMissingColumnError(error: any = None) -> bool {
    return chain_matches(
        error,
        rx(
            r"""no such column|has no column named|column ("[^"]+"|[\w.]+) (of relation "[^"]+" )?does not exist|unknown column""",
            "i",
        ),
        ["42703", 1054, "ER_BAD_FIELD_ERROR"],
    );
}

def isUniqueConstraintError(error: any = None) -> bool {
    return chain_matches(
        error,
        rx(
            r"UNIQUE constraint failed|duplicate key value violates unique constraint|duplicate entry",
            "i",
        ),
    );
}
