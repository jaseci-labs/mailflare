glob:priv PAGE: int = 1000;

# Pages per run, so one prefix cannot use a whole run's request budget; the next run continues.
glob:priv MAX_PAGES: int = 5;

"""Deletes objects under `prefix` last written more than `maxAgeMs` ago; returns how many.

Listing is by key, not age, so a run looks at a bounded number of pages and the next scheduled
run picks up the rest.
"""
async def sweepStaleObjects(bucket: any, prefix: str, maxAgeMs: float, now: any = None) -> int {
    if now is None {
        now = new(globalThis.Date);
    }
    removed = 0;
    cursor: any = None;
    for page in range(MAX_PAGES) {
        listing = await bucket.list(record({"prefix": prefix, "cursor": cursor, "limit": PAGE}));
        stale = [o.key for o in listing.objects if now.getTime() - o.uploaded.getTime() > maxAgeMs];
        if stale {
            await bucket.delete(stale);
            removed += len(stale);
        }
        if not at(listing, "truncated") or not at(listing, "cursor") {
            break;
        }
        cursor = at(listing, "cursor");
    }
    return removed;
}
