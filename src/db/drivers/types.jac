# A driver is only an executor turning `(sql, params)` into rows: drizzle's proxy drivers and the
# D1-compatible `env.DB` both run on it. `transaction` is absent for HTTP drivers that cannot hold
# one open; `OpenOptions.shared` keeps Node pools open (Workers cannot reuse sockets).
type RowMode = any;
type QueryResult = any;
type SqlExecutor = any;
type OpenOptions = any;

# `?` to `$1, $2, ...` outside string literals, quoted identifiers and comments.
def numberPlaceholders(sql: any) -> str {
    (out, index, i) = ("", 0, 0);
    while i < sql.length {
        (ch, stop, piece) = (sql.charAt(i), i + 1, None);
        if ch in ["'", "\""] {
            close = sql.indexOf(ch, i + 1);
            # Doubled quotes are escapes inside the literal.
            while close != -1 and sql.charAt(close + 1) == ch {
                close = sql.indexOf(ch, close + 2);
            }
            stop = sql.length if close == -1 else close + 1;
        } elif ch == "-" and sql.charAt(i + 1) == "-" {
            end = sql.indexOf("\n", i);
            stop = sql.length if end == -1 else end;
        } elif ch == "?" {
            index += 1;
            piece = f"${index}";
        }
        (out, i) = (out + either(piece, sql.slice(i, stop)), stop);
    }
    return out;
}

# Convert values the drivers do not all accept the same way.
def normalizeParam(value: any = None) -> any {
    if value is None {
        return NULL;
    }
    if isinstance(value, globalThis.Date) {
        return globalThis.Math.floor(value.getTime() / 1000);
    }
    if globalThis.ArrayBuffer.isView(value) and not isinstance(value, globalThis.Uint8Array) {
        return new(globalThis.Uint8Array, value.buffer, value.byteOffset, value.byteLength);
    }
    buffer = isinstance(value, globalThis.ArrayBuffer);
    return new(globalThis.Uint8Array, value) if buffer else value;
}

def toObjects(columns: any, rows: any) -> any {
    pairs = lambda (row: any) -> any { [[name, row.at(i)] for (i, name) in enumerate(columns)] };
    return [globalThis.Object.fromEntries(pairs(row)) for row in rows];
}

# Opens the driver the first time it is needed, so unused drivers are never imported; a failed
# open is forgotten and retried.
def lazyExecutor(dialect: any, opener: any) -> any {
    st = {"pending": None};
    def forget(error: any) -> any {
        st["pending"] = None;
        return globalThis.Promise.reject(error);
    }
    def ready -> any {
        if st["pending"] is None {
            st["pending"] = opener().catch(forget);
        }
        return st["pending"];
    }
    async def q(sql: any, params: any, mode: any) -> any {
        return await (await ready()).query(sql, params, mode);
    }
    async def transaction(fn: any) -> any {
        inner = await ready();
        return await (inner.transaction(fn) if getattr(inner, "transaction", None) else fn(inner));
    }
    async def close -> any {
        if st["pending"] is not None {
            inner = await st["pending"];
            if getattr(inner, "close", None) {
                await inner.close();
            }
        }
        st["pending"] = None;
    }
    return record({
        "dialect": dialect,
        "query": lambda (sql: any, params: any, mode: any) -> any { promise(q(sql, params, mode)) },
        "transaction": lambda (fn: any) -> any { promise(transaction(fn)) },
        "close": lambda -> any { promise(close()) },
    });
}
