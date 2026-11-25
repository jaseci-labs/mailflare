"""Rows move between Inbox and Promotions only where Promotions is on, for people who may manage
the mailbox, and only for received mail. Off mailboxes see nothing."""
def canMoveCategory(given: any) -> bool {
    return given["mode"] in ["show", "separate"]
        and given["permission"] == "full_access"
        and given["direction"] == "inbound"
        and given["status"] == "received";
}

"""The list a reader page was opened from, by its path: only Inbox and Promotions offer a move, as their list rows do."""
def readerFolderOf(pathname: str) -> str {
    parts = pathname.split("/");
    return parts[1] if len(parts) > 1 and parts[1] in ["inbox", "promotions"] else "other";
}

"""A promotion goes back to Inbox; anything else (unclassified or already `primary`) goes to Promotions."""
def moveTargetFor(category: any = None) -> str {
    return "inbox" if category == "promotions" else "promotions";
}

"""Inbox rows carry the chip only in `show` mode: in `separate` they are hidden from Inbox, and off shows nothing new."""
def showsPromotionChip(given: any) -> bool {
    return given["folder"] == "inbox"
        and not at(given, "folderId")
        and given["mode"] == "show"
        and given["category"] == "promotions";
}

"""Whether the folder on screen stops listing a message once it moves to `target`."""
def moveLeavesFolder(folder: str, target: str, mode: any = None) -> bool {
    if folder == "promotions" {
        return target == "inbox";
    }
    return folder == "inbox" and target == "promotions" and mode == "separate";
}

"""What JavaScript threw, where Jac caught it as its own exception."""
def:priv thrown(error: any) -> any {
    return getattr(error, "js", error);
}

"""Runs `worker` over `items` with at most `limit` in flight; results keep the input order and a failure never stops the rest."""
async def runLimited(items: any, limit: any, worker: any) -> any {
    # A worker may answer without a promise, and what it throws is kept as thrown, not as Jac caught it.
    settled = globalThis.Promise.resolve.bind(globalThis.Promise);
    results: any = new(globalThis.Array, len(items));
    queue = list(range(len(items)));
    async def lane {
        while queue {
            index = queue.pop(0);
            try {
                results[index] = record({"ok": True, "value": await settled(worker(items[index]))});
            } except Exception as error {
                results[index] = record({"ok": False, "error": thrown(error)});
            }
        }
    }
    lanes = record({"length": globalThis.Math.min(limit, len(items))});
    await globalThis.Promise.all(globalThis.Array.from(lanes, lambda -> any { lane() }));
    return results;
}

"""`moved` counts messages whose request succeeded, `changed` the rows that actually switched category (the rest were already there)."""
def summarizeMoves(results: any) -> dict[str, any] {
    (moved, changed) = (0, 0);
    for result in results {
        if result["ok"] {
            moved += 1;
            changed += result["value"]["changed"];
        }
    }
    return {
        "total": len(results),
        "moved": moved,
        "failed": len(results) - moved,
        "changed": changed,
    };
}

def moveToastCopy(target: str, summary: any) -> dict[str, any] {
    place = "Inbox" if target == "inbox" else "Promotions";
    if summary["moved"] == 0 {
        return {"key": "promotions.move.failed"};
    }
    if summary["failed"] > 0 {
        return {
            "key": "promotions.move.partial",
            "vars": {"moved": summary["moved"], "total": summary["total"]},
        };
    }
    if summary["total"] == 1 {
        return {"key": f"promotions.move.done{place}"};
    }
    return {"key": f"promotions.move.doneMany{place}", "vars": {"count": summary["total"]}};
}

""" "Always for <sender>" only follows a clean move of a message that has a sender address on record."""
def canOfferAlways(summary: any, senderAddress: any = None) -> bool {
    return bool(senderAddress) and summary["failed"] == 0 and summary["moved"] > 0;
}

"""The sender rule re-files a bounded slice (90 days, 500 rows); older mail is left, and the copy says so."""
def senderResultCopy(result: any) -> dict[str, any] {
    if result["remainingOlder"] > 0 {
        return {
            "key": "promotions.always.resultOlder",
            "vars": {"changed": result["changed"], "remaining": result["remainingOlder"]},
        };
    }
    if result["changed"] > 0 {
        return {"key": "promotions.always.result", "vars": {"changed": result["changed"]}};
    }
    return {"key": "promotions.always.nothing"};
}

"""WCAG 2.2.1: hovering or focusing the toast stops its countdown."""
def isToastPaused(holds: any) -> any {
    return holds["hover"] or holds["focus"];
}

def remainingAfter(remaining: any, startedAt: any, now: any) -> any {
    return globalThis.Math.max(0, remaining - globalThis.Math.max(0, now - startedAt));
}

type MoveTarget = any;
type MoveSummary = any;
type Settled = any;
type CopyDescriptor = any;
