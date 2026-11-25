# Whether an error in the chain has a driver code (`code`/`errno` from pg and mysql2: no wording or
# locale) or a message matching `pattern`; Drizzle wraps driver errors, keeping them on `cause`.
def:priv chain_matches(error: any, pattern: str, codes: list[any] = []) -> bool {
    (current, seen, regex) = (error, new(globalThis.Set), rx(pattern, "i"));
    while current and not seen.has(current) {
        seen.add(current);
        o = is_object(current);
        coded = o and any([c is current["code"] or c is current["errno"] for c in codes]);
        is_err = isinstance(current, globalThis.Error);
        if coded or regex.test(current.message if is_err else globalThis.String(current)) {
            return True;
        }
        current = current["cause"] if o and globalThis.Reflect.has(current, "cause") else None;
    }
    return False;
}

"""The table does not exist yet, for features whose migration may not be applied."""
def isMissingTableError(error: any = None) -> bool {
    missing = r"""no such table|relation "[^"]+" does not exist|table '[^']+' doesn't exist""";
    return chain_matches(error, missing, ["42P01", 1146, "ER_NO_SUCH_TABLE"]);
}

"""A column added by a migration that may not be applied yet."""
def isMissingColumnError(error: any = None) -> bool {
    named = r"""column ("[^"]+"|[\w.]+) (of relation "[^"]+" )?does not exist""";
    missing = f"no such column|has no column named|{named}|unknown column";
    return chain_matches(error, missing, ["42703", 1054, "ER_BAD_FIELD_ERROR"]);
}

def isUniqueConstraintError(error: any = None) -> bool {
    unique = "duplicate key value violates unique constraint|duplicate entry";
    unique = f"UNIQUE constraint failed|{unique}";
    return chain_matches(error, unique);
}
