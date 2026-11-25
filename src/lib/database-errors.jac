# Whether an error in the chain has a driver code (`code`/`errno` from pg and mysql2: no wording or
# locale) or a message matching `regex`; Drizzle wraps driver errors, keeping them on `cause`.
# Called around many queries, so it is plain JavaScript calls: no per-call regex, no dispatch.
glob:priv MISSING_TABLE: any = rx(
              r"""no such table|relation "[^"]+" does not exist|table '[^']+' doesn't exist""", "i"
          ),
          MISSING_COLUMN: any = rx(
              r"""no such column|has no column named|column ("[^"]+"|[\w.]+) (of relation "[^"]+" )?does not exist|unknown column""",
              "i",
          ),
          UNIQUE: any = rx(
              "UNIQUE constraint failed|duplicate key value violates unique constraint|duplicate entry",
              "i",
          ),
          TABLE_CODES: list[any] = ["42P01", 1146, "ER_NO_SUCH_TABLE"],
          COLUMN_CODES: list[any] = ["42703", 1054, "ER_BAD_FIELD_ERROR"],
          NO_CODES: list[any] = [];

def:priv chain_matches(error: any, regex: any, codes: list[any]) -> bool {
    current: any = error;
    seen: any = None;
    while globalThis.Boolean(current) {
        # Most errors have no cause: only a chain needs the set that stops a cycle.
        if seen is None {
            seen = new(globalThis.Set);
        } elif globalThis.Set.prototype.has.call(seen, current) {
            return False;
        }
        globalThis.Set.prototype.add.call(seen, current);
        o = is_object(current);
        if o {
            code = globalThis.Reflect.get(current, "code");
            errno = globalThis.Reflect.get(current, "errno");
            for c in codes {
                if c is code or c is errno {
                    return True;
                }
            }
        }
        text: any = globalThis.Reflect.get(current, "message")
            if isinstance(current, globalThis.Error)
            else globalThis.String(current);
        if globalThis.RegExp.prototype.test.call(regex, text) {
            return True;
        }
        if not o or not globalThis.Reflect.has(current, "cause") {
            return False;
        }
        current = globalThis.Reflect.get(current, "cause");
    }
    return False;
}

"""The table does not exist yet, for features whose migration may not be applied."""
def isMissingTableError(error: any = None) -> bool {
    return chain_matches(error, MISSING_TABLE, TABLE_CODES);
}

"""A column added by a migration that may not be applied yet."""
def isMissingColumnError(error: any = None) -> bool {
    return chain_matches(error, MISSING_COLUMN, COLUMN_CODES);
}

def isUniqueConstraintError(error: any = None) -> bool {
    return chain_matches(error, UNIQUE, NO_CODES);
}
