# Deletes objects under `prefix` last written more than `maxAgeMs` ago and returns how many. Listing
# is by key, not age, so a run reads at most 5 pages (one prefix cannot use a whole run's request
# budget) and the next scheduled run picks up the rest.
async def sweepStaleObjects(bucket: any, prefix: str, maxAgeMs: any, now: any = None) -> int {
    moment = (new(globalThis.Date) if now is None else now).getTime();
    (removed, cursor) = (0, None);
    for _ in range(5) {
        listing = await bucket.list(record({"prefix": prefix, "cursor": cursor, "limit": 1000}));
        stale = [o.key for o in listing.objects if moment - o.uploaded.getTime() > maxAgeMs];
        if stale {
            await bucket.delete(stale);
            removed += len(stale);
        }
        cursor = at(listing, "cursor");
        if not at(listing, "truncated") or not cursor {
            break;
        }
    }
    return removed;
}
