# Rows move between Inbox and Promotions only where Promotions is on, for managers, received mail only.
def canMoveCategory(g: any) -> bool {
    want = ("full_access", "inbound", "received");
    return g["mode"] in ["show", "separate"]
        and (g["permission"], g["direction"], g["status"]) == want;
}

# Only Inbox and Promotions offer a move, as their list rows do.
def readerFolderOf(pathname: str) -> str {
    f = (pathname.split("/") + [""])[1];
    return f if f in ["inbox", "promotions"] else "other";
}

def moveTargetFor(category: any = None) -> str {
    return "inbox" if category == "promotions" else "promotions";
}

# Inbox rows carry the chip only in `show` mode: `separate` hides them from Inbox.
def showsPromotionChip(g: any) -> bool {
    return not at(g, "folderId")
        and (g["folder"], g["mode"], g["category"]) == ("inbox", "show", "promotions");
}

def moveLeavesFolder(folder: str, target: str, mode: any = None) -> bool {
    if folder == "promotions" {
        return target == "inbox";
    }
    return folder == "inbox" and target == "promotions" and mode == "separate";
}

# At most `limit` in flight, input order kept; a failure, kept as thrown, never stops the rest.
async def runLimited(items: any, limit: any, worker: any) -> any {
    results: any = new(globalThis.Array, len(items));
    queue = list(range(len(items)));
    good = lambda (v: any) -> any { record({"ok": True, "value": v}) };
    bad = lambda (e: any) -> any { record({"ok": False, "error": e}) };
    async def lane {
        while queue {
            i = queue.pop(0);
            call = new(globalThis.Promise, lambda (ok: any) -> any { ok(worker(items[i])) });
            results[i] = await call.then(good, bad);
        }
    }
    lanes = record({"length": globalThis.Math.min(limit, len(items))});
    await globalThis.Promise.all(globalThis.Array.from(lanes, lambda -> any { lane() }));
    return results;
}

# `changed` counts rows that actually switched category (the rest were already there).
def summarizeMoves(results: any) -> dict[str, any] {
    done = [r["value"]["changed"] for r in results if r["ok"]];
    (n, moved) = (len(results), len(done));
    return {"total": n, "moved": moved, "failed": n - moved, "changed": sum(done)};
}

# A translation key and its variables, if any.
def:priv copy(key: str, vars: any = None) -> dict[str, any] {
    d: dict[str, any] = {"key": f"promotions.{key}"};
    return d if vars is None else {**d, "vars": vars};
}

def moveToastCopy(target: str, s: any) -> dict[str, any] {
    (place, moved, n) = ("Inbox" if target == "inbox" else "Promotions", s["moved"], s["total"]);
    if moved == 0 or s["failed"] > 0 {
        return copy("move.partial", {"moved": moved, "total": n}) if moved else copy("move.failed");
    }
    return copy(f"move.done{place}") if n == 1 else copy(f"move.doneMany{place}", {"count": n});
}

def canOfferAlways(s: any, senderAddress: any = None) -> bool {
    return bool(senderAddress) and s["failed"] == 0 and s["moved"] > 0;
}

# The sender rule re-files a bounded slice (90 days, 500 rows); the copy says older mail is left.
def senderResultCopy(r: any) -> dict[str, any] {
    (changed, older) = (r["changed"], r["remainingOlder"]);
    if older > 0 {
        return copy("always.resultOlder", {"changed": changed, "remaining": older});
    }
    return copy("always.result", {"changed": changed}) if changed > 0 else copy("always.nothing");
}

# WCAG 2.2.1: hovering or focusing the toast stops its countdown.
def isToastPaused(holds: any) -> any {
    return holds["hover"] or holds["focus"];
}

def remainingAfter(remaining: any, startedAt: any, now: any) -> any {
    return globalThis.Math.max(0, remaining - globalThis.Math.max(0, now - startedAt));
}

type MoveTarget = any;
type MoveSummary = any;
type CopyDescriptor = any;
