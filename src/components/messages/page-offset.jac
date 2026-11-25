"""The page to show after the visible page empties. A page still within the new total is waiting
for its backfill, so the offset stays; only an out-of-range page (or an empty folder) moves back."""
def getEmptyPageOffset(offset: any, total: any, limit: any) -> any {
    if offset == 0 or offset < total {
        return NULL;
    }
    return globalThis.Math.floor((total - 1) / limit) * limit if total > 0 else 0;
}
