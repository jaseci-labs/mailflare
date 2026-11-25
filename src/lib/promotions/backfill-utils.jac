# One run reads at most 25 messages, every 5 minutes. A promoted row costs about 6 D1 row writes
# (row, indexes, change log): 2,000 rows a day for the installation is ~12,000 of D1 Free's 100,000.
glob BACKFILL_BATCH = 25,
     BACKFILL_DAILY_CAP = 2000;

# Mail of the last 90 days; 32 KiB of head holds every header the detector reads; the cursor is
# saved every 10 rows (a killed run loses one chunk); a `running` row idle 15 minutes is dead;
# 3 runs dying with no progress fail the job.
glob BACKFILL_WINDOW_DAYS = 90,
     BACKFILL_HEAD_BYTES = 32768,
     BACKFILL_CHUNK = 10,
     BACKFILL_STALE_MS = 15 * 60000,
     BACKFILL_MAX_STALLS = 3;

# The UTC day a timestamp falls on, as a whole number.
def backfillDay(now: any) -> int {
    return globalThis.Math.floor(now.getTime() / 86400000);
}

# Keyset position `(created_at, id)` of the last row handled, as JSON in `backfill_cursor`.
def serializeCursor(cursor: any) -> str {
    return globalThis.JSON.stringify(record(cursor));
}

def parseCursor(value: any) -> any {
    try {
        p = globalThis.JSON.parse(value) if value else NULL;
        (created, id) = (p["createdAt"], p["id"]);
    } except Exception {
        return NULL;
    }
    ok = globalThis.Number.isFinite(created) and globalThis.String(id) is id;
    return {"createdAt": created, "id": id} if ok else NULL;
}

def backfillCutoff(now: any) -> any {
    return new(globalThis.Date, now.getTime() - BACKFILL_WINDOW_DAYS * 86400000);
}

type BackfillCursor = any;
