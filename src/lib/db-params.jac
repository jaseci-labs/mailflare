"""D1 rejects a statement with more than 100 bound parameters."""
glob D1_MAX_BOUND_PARAMETERS: int = 100;

"""
Runs a query that filters on `inArray(column, batch)` once per batch of `ids`, so no statement binds
more than D1's limit, and returns every batch's rows together in batch order. The room for ids is
derived from the query's other parameters, so the caller does not count them. Ids are deduplicated;
callers that need a global order must sort the result. Assumes the id list appears once in the
query. Mailbox-id lists are fixed parameters, not batched, so accounts with about 90 or more
accessible mailboxes are out of scope.
"""
async def selectInBatches(ids: any, build: any) -> any {
    unique: any = globalThis.Array.from(new(globalThis.Set, ids));
    fixed = len(build(unique[0:1]).toSQL().params) - 1 if len(unique) else 0;
    (size, rows) = (globalThis.Math.max(1, D1_MAX_BOUND_PARAMETERS - fixed), []);
    for index in range(0, len(unique), size) {
        rows.extend(await build(unique[index:index + size]));
    }
    return rows;
}
