# A `D1Database` over any SqlExecutor, for the raw `env.DB.prepare(...)` call sites: SQL keeps D1's
# `?` placeholders, numbered here for PostgreSQL.
glob:priv ZERO: dict[str, int] = {k: 0 for k in "duration size_after rows_read".split()};

# A promise of `f()` that also rejects when `f` throws, as an async function's would.
def:priv later(f: any) -> any {
    return new(globalThis.Promise, lambda (ok: any) -> any { ok(f()) });
}

# JavaScript calls `bind(a, b, ...)` with its values spread: a Proxy's apply trap gathers them.
glob:priv SPREAD: any = record({
    "apply": lambda (f: any, me: any, args: any) -> any { me.rebind(args) },
});

def:priv outcome(r: any) -> any {
    (n, last) = (r.affectedRows, either(at(r, "insertId"), 0));
    meta = {**ZERO, "rows_written": n, "last_row_id": last, "changed_db": n > 0, "changes": n};
    return record({"results": r.rows, "success": True, "meta": record(meta)});
}

obj CompatStatement(globalThis.Object) {
    has db: any,
        sql: any,
        params: any,
        bind: any;

    def init(db: any, sql: any, params: any = None) {
        super.init();
        (self.db, self.sql, self.params) = (db, sql, [] if params is None else params);
        self.bind = new(globalThis.Proxy, globalThis.Function.prototype, SPREAD);
    }

    def rebind(values: any) -> any {
        return CompatStatement(self.db, self.sql, [normalizeParam(v) for v in values]);
    }

    # Statements without parameters (migrations) are sent untouched, so a `?` in a function body survives.
    def text -> str {
        numbered = self.db.dialect == "postgres" and len(self.params) > 0;
        return numberPlaceholders(self.sql) if numbered else self.sql;
    }

    def execute(executor: any) -> any {
        return later(lambda -> any { executor.query(self.text(), self.params, "object") });
    }

    def:priv send(mode: str) -> any {
        return later(lambda -> any { self.db.executor().query(self.text(), self.params, mode) });
    }

    def run -> any {
        return self.send("object").then(outcome);
    }

    def all -> any {
        return self.run();
    }

    def first(column: any = None) -> any {
        def pick(r: any) -> any {
            row = r.rows.at(0);
            return NULL if not row else (row[column] if column else row);
        }
        return self.send("object").then(pick);
    }

    def raw -> any {
        return self.send("array").then(lambda (r: any) -> any { r.rows });
    }
}

obj CompatDatabase(globalThis.Object) {
    has dialect: any,
        base: any,
        active: any;

    def init(dialect: any, base: any, active: any = None) {
        super.init();
        (self.dialect, self.base, self.active) = (dialect, base, active);
    }

    def executor -> any {
        return either(self.active(), self.base) if self.active else self.base;
    }

    def prepare(sql: str) -> any {
        return CompatStatement(self, sql);
    }

    def batch(statements: any) -> any {
        async def each(executor: any) -> any {
            results: list[any] = [];
            for s in statements {
                results.append(outcome(await s.execute(executor)));
            }
            return results;
        }
        run = lambda (executor: any) -> any { promise(each(executor)) };
        tx = getattr(self.base, "transaction", None);
        return later(lambda -> any { self.base.transaction(run) if tx else run(self.base) });
    }

    def exec(sql: str) -> any {
        rows = lambda (r: any) -> any { record({"count": 1, "duration": 0, "rows": r.rows}) };
        return later(lambda -> any { self.base.query(sql, [], "object") }).then(rows);
    }

    def dump -> any {
        error = new(globalThis.Error, "dump() is not available on external databases.");
        return globalThis.Promise.reject(error);
    }
}
