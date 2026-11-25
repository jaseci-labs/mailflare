glob:priv MODES: list[str] = ["off", "show", "separate"],
          REQUEUE: dict[str, any] = {
              "backfillStatus": "pending",
              "backfillStalls": 0,
              "backfillError": NULL,
              "backfillCursor": NULL,
              "backfillScanned": 0,
          };

def parseModeBody(body: any) -> dict[str, any] {
    mode = body["mode"] if globalThis.Object(body) is body else None;
    if globalThis.String(mode) is not mode or mode not in MODES {
        return {"error": "mode must be off, show or separate"};
    }
    return {"mode": mode};
}

"""Backfill fields to write with a mode change. Moving away from off queues the backfill unless it is
pending, running or done; an idle or failed job restarts from a clean state. Saving a non-off mode while the
job is failed also restarts it, which is what the Settings "Try again" button sends. Other changes leave it alone."""
def backfillPatchForModeChange(current: any, target: str) -> dict[str, any] {
    was_off = not current or current["mode"] == "off";
    status = current["backfillStatus"] if current else None;
    if target != "off" and not was_off and status == "failed" {
        return dict(REQUEUE);
    }
    if not was_off or target == "off" {
        return {} if current else {"backfillStatus": "idle"};
    }
    if current and status not in ["idle", "failed"] {
        return {};
    }
    return dict(REQUEUE);
}

def describeBackfill(row: any) -> dict[str, any] {
    if not row {
        return {"status": "idle", "scanned": 0};
    }
    described = {"status": row["backfillStatus"], "scanned": row["backfillScanned"]};
    if row["backfillStatus"] == "failed" and row["backfillError"] {
        described["error"] = row["backfillError"];
    }
    return described;
}

"""A promotion in a `separate` mailbox is not announced (no popup, no push); the list still refreshes."""
def isSilentPromotion(category: any = None, mode: any = None) -> bool {
    return category == "promotions" and mode == "separate";
}

type BackfillStatus = any;
type BackfillPatch = any;
