glob:priv REQUEUE: list[str] = "Status Stalls Error Cursor Scanned".split();

def parseModeBody(body: any) -> dict[str, any] {
    mode = body["mode"] if is_object(body) else None;
    if globalThis.String(mode) is not mode or mode not in ["off", "show", "separate"] {
        return {"error": "mode must be off, show or separate"};
    }
    return {"mode": mode};
}

# Leaving off queues the backfill unless it is pending, running or done (idle or failed restart clean);
# saving a non-off mode while failed restarts it too ("Try again"). Other changes leave it alone.
def backfillPatchForModeChange(current: any, target: str) -> dict[str, any] {
    s = current["backfillStatus"] if current else None;
    fresh = not current or s == "failed" or (current["mode"] == "off" and s == "idle");
    if target != "off" and fresh {
        return dict(zip([f"backfill{k}" for k in REQUEUE], ["pending", 0, NULL, NULL, 0]));
    }
    return {} if current else {"backfillStatus": "idle"};
}

def describeBackfill(row: any) -> dict[str, any] {
    if not row {
        return {"status": "idle", "scanned": 0};
    }
    d = {"status": row["backfillStatus"], "scanned": row["backfillScanned"]};
    err = row["backfillError"];
    return {**d, "error": err} if d["status"] == "failed" and err else d;
}

# A promotion in a `separate` mailbox is not announced (no popup, no push); the list still refreshes.
def isSilentPromotion(category: any = None, mode: any = None) -> bool {
    return category == "promotions" and mode == "separate";
}
