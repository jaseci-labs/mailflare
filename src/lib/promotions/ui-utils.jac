glob PROMOTION_MODE_OPTIONS: any = [
    record({"value": "off", "labelKey": "settings.promotions.modeOff"}),
    record({"value": "show", "labelKey": "settings.promotions.modeShow"}),
    record({"value": "separate", "labelKey": "settings.promotions.modeSeparate"}),
];

glob:priv NOTICE_KEYS: dict[str, str] = {
    "pending": "settings.promotions.backfillPending",
    "running": "settings.promotions.backfillRunning",
    "done": "settings.promotions.backfillDone",
    "failed": "settings.promotions.backfillFailed",
};

"""The Promotions nav entry exists only when some mailbox in scope has it on."""
def hasActivePromotions(modes: any = None) -> bool {
    return bool(modes) and len([1 for (_, mode) in entries(modes) if mode != "off"]) > 0;
}

"""Mirrors the server: changing a mailbox's mode needs full access."""
def canManagePromotions(permission: any = None) -> bool {
    return permission == "full_access";
}

"""What the Settings row says about the 90-day sort of existing mail."""
def getBackfillNotice(backfill: any = None) -> dict[str, any] {
    status = backfill["status"] if backfill else None;
    if globalThis.String(status) is not status or status not in NOTICE_KEYS {
        return {"kind": "none"};
    }
    notice = {"kind": status, "key": NOTICE_KEYS[status]};
    if status == "failed" {
        return {**notice, "error": at(backfill, "error", NULL), "retry": True};
    }
    return notice if status == "pending" else {**notice, "vars": {"count": backfill["scanned"]}};
}

"""Message for a failed mode save. 409 MIGRATION_REQUIRED happens on servers that have not applied the promotions migration yet."""
def getModeErrorKey(status: any, code: any = None) -> str {
    if status == 409 and code == "MIGRATION_REQUIRED" {
        return "settings.promotions.migrationRequired";
    }
    return "settings.promotions.forbidden" if status == 403 else "settings.promotions.saveFailed";
}

"""The folder counts that move, leaving out a count that does not."""
def:priv deltas(inbox: any, promotions: any) -> dict[str, any] {
    return {
        k: v
        for (k, v) in [("inboxUnreadDelta", inbox), ("promotionsUnreadDelta", promotions)]
        if v
    };
}

"""Which folder counts a read/unread flip of `flip` messages moves, from the list the row is in.
Inbox rows count toward Inbox, and also toward Promotions when they are promotions in a mailbox that has it on;
Promotions rows count toward Promotions, and toward Inbox too in `show` mode, where they are listed in both.
Null when no count moves."""
def unreadDeltas(context: any, flip: any) -> any {
    if not flip or at(context, "folderId") {
        return NULL;
    }
    mode = at(context, "mode");
    on = bool(mode) and mode != "off";
    if context["folder"] == "inbox" {
        return deltas(flip, flip if on and at(context, "category") == "promotions" else 0);
    }
    if context["folder"] == "promotions" and on {
        return deltas(flip if mode == "show" else 0, flip);
    }
    return NULL;
}

def mergeUnreadDeltas(a: any, b: any) -> any {
    if not a {
        return b;
    }
    if not b {
        return a;
    }
    return deltas(
        at(a, "inboxUnreadDelta", 0) + at(b, "inboxUnreadDelta", 0),
        at(a, "promotionsUnreadDelta", 0) + at(b, "promotionsUnreadDelta", 0),
    );
}

def negateUnreadDeltas(given: any) -> any {
    if not given {
        return NULL;
    }
    return deltas(-at(given, "inboxUnreadDelta", 0), -at(given, "promotionsUnreadDelta", 0));
}

type PromotionModeValue = any;
type BackfillState = any;
type BackfillNotice = any;
type UnreadDeltaContext = any;
type UnreadDeltas = any;
