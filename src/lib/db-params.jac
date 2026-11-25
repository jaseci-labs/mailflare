"""D1 rejects a statement with more than 100 bound parameters."""
glob D1_MAX_BOUND_PARAMETERS: int = 100;

"""
Runs a query that filters on `inArray(column, batch)` once per batch of `ids`, so no statement
binds more than D1's limit, and returns every batch's rows together in batch order. The room left
for ids is derived from the query itself (its other conditions' parameters), so the caller does not
count them. Ids are deduplicated; callers that need a global order must sort the result.

Assumes the id list appears once in the query. Mailbox-id lists are part of the fixed parameters
and are not batched, so accounts with about 90 or more accessible mailboxes are out of scope.
"""
async def selectInBatches(ids: any, build: any) -> any {
    unique: any = globalThis.Array.from(new(globalThis.Set, ids));
    if not len(unique) {
        return [];
    }
    fixed = len(build(unique[0:1]).toSQL().params) - 1;
    size = max(1, D1_MAX_BOUND_PARAMETERS - fixed);
    rows: list[any] = [];
    for index in range(0, len(unique), size) {
        rows.extend(await build(unique[index:index + size]));
    }
    return rows;
}
