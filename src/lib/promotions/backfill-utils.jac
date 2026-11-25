glob BACKFILL_BATCH = 25,  # One run reads at most this many messages: 25 every 5 minutes.
     # Rows the backfill may read in a day across the whole installation. A promoted row costs about
     # 6 D1 row writes (the row, its indexes, the change-log entry), so 2,000 rows is about 12,000
     # writes of D1 Free's 100,000 a day.
     BACKFILL_DAILY_CAP = 2000,
     # Only mail of the last 90 days is classified.
     BACKFILL_WINDOW_DAYS = 90,
     # Bytes read from the start of each raw message: enough for every header the detector looks at.
     BACKFILL_HEAD_BYTES = 32768,
     # Rows handled between two saves of the cursor, so a killed run loses at most one chunk.
     BACKFILL_CHUNK = 10,
     # A `running` row not touched for this long belongs to a run that died.
     BACKFILL_STALE_MS = 15 * 60000,
     # Consecutive runs that died without saving any progress before the job is marked failed.
     BACKFILL_MAX_STALLS = 3;

"""The UTC day a timestamp falls on, as a whole number."""
def backfillDay(now: any) -> int {
    return globalThis.Math.floor(now.getTime() / 86400000);
}

"""The keyset position `(created_at, id)` of the last row handled, as the JSON `backfill_cursor` stores."""
def serializeCursor(cursor: any) -> str {
    return globalThis.JSON.stringify(record(cursor));
}

def parseCursor(value: any) -> any {
    if not value {
        return NULL;
    }
    try {
        parsed = globalThis.JSON.parse(value);
        (created, id) = (parsed["createdAt"], parsed["id"]);
    } except Exception {
        return NULL;
    }
    if globalThis.Number.isFinite(created) and globalThis.String(id) is id {
        return {"createdAt": created, "id": id};
    }
    return NULL;
}

def backfillCutoff(now: any) -> any {
    return new(globalThis.Date, now.getTime() - BACKFILL_WINDOW_DAYS * 86400000);
}

type BackfillCursor = any;
