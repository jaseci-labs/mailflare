# A `D1Database` over any SqlExecutor for raw `env.DB.prepare(...)`; `?` is numbered for PostgreSQL.
# Every raw query passes through here, so the statement path makes no closures and no tuples: on a
# JavaScript host each lambda is a new function object and each tuple a runtime value.

# JavaScript calls `bind(a, b, ...)` with its values spread, which a method's `*values` does not
# take: one Proxy, shared by every statement, gathers them in its apply trap (`me` is the statement).
glob:priv BIND: any = new(
    globalThis.Proxy,
    globalThis.Function.prototype,
    record({"apply": lambda (f: any, me: any, a: any) -> any { me.rebind(a) }}),
);

def:priv outcome(r: any) -> any {
    n = r.affectedRows;
    meta = record({
        "duration": 0,
        "size_after": 0,
        "rows_read": 0,
        "rows_written": n,
        "last_row_id": either(at(r, "insertId"), 0),
        "changed_db": n > 0,
        "changes": n,
    });
    return record({"results": r.rows, "success": True, "meta": meta});
}

def:priv first_row(r: any, column: any) -> any {
    row = r.rows.at(0);
    if not row {
        return NULL;
    }
    return row[column] if column else row;
}

obj CompatStatement(globalThis.Object) {
    def init(db: any, sql: any, params: any = None) {
        super.init();
        self.db = db;
        self.sql = sql;
        self.params = [] if params is None else params;
        self.bind = BIND;
    }

    def rebind(values: any) -> any {
        return CompatStatement(self.db, self.sql, [normalizeParam(v) for v in values]);
    }

    # Statements without parameters (migrations) are sent untouched, so a `?` in a function body survives.
    def text -> str {
        numbered = self.db.dialect == "postgres" and len(self.params) > 0;
        return numberPlaceholders(self.sql) if numbered else self.sql;
    }

    async def execute(executor: any, mode: str = "object") -> any {
        ex = executor or self.db.executor();
        return await ex.query(self.text(), self.params, mode);
    }

    async def run -> any {
        return outcome(await self.execute(None));
    }

    async def all -> any {
        return outcome(await self.execute(None));
    }

    async def first(column: any = None) -> any {
        return first_row(await self.execute(None), column);
    }

    async def raw -> any {
        return (await self.execute(None, "array")).rows;
    }
}

obj CompatDatabase(globalThis.Object) {
    def init(dialect: any, base: any, active: any = None) {
        super.init();
        self.dialect = dialect;
        self.base = base;
        self.active = active;
    }

    def executor -> any {
        return either(self.active(), self.base) if self.active else self.base;
    }

    def prepare(sql: str) -> any {
        return CompatStatement(self, sql);
    }

    def batch(statements: any) -> any {
        async def each(executor: any) -> any {
            return [outcome(await s.execute(executor)) for s in statements];
        }
        run = lambda (executor: any) -> any { promise(each(executor)) };
        tx = getattr(self.base, "transaction", None);
        return promise(self.run_batch(run, tx));
    }

    async def run_batch(run: any, tx: any) -> any {
        return await (self.base.transaction(run) if tx else run(self.base));
    }

    async def exec(sql: str) -> any {
        r = await self.base.query(sql, [], "object");
        return record({"count": 1, "duration": 0, "rows": r.rows});
    }

    def dump -> any {
        error = new(globalThis.Error, "dump() is not available on external databases.");
        return globalThis.Promise.reject(error);
    }
}
