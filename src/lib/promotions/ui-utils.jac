glob PROMOTION_MODE_OPTIONS: any = [
    record({"value": m, "labelKey": f"settings.promotions.mode{m.capitalize()}"})
    for m in ["off", "show", "separate"]
];

# The Promotions nav entry exists only when some mailbox in scope has it on.
def hasActivePromotions(modes: any = None) -> bool {
    return bool(modes) and any([mode != "off" for (_, mode) in entries(modes)]);
}

# Mirrors the server: changing a mailbox's mode needs full access.
def canManagePromotions(permission: any = None) -> bool {
    return permission == "full_access";
}

# What the Settings row says about the 90-day sort of existing mail.
def getBackfillNotice(b: any = None) -> dict[str, any] {
    s = b["status"] if b else None;
    if s not in ["pending", "running", "done", "failed"] {
        return {"kind": "none"};
    }
    n = {"kind": s, "key": f"settings.promotions.backfill{s.capitalize()}"};
    if s == "failed" {
        return {**n, "error": at(b, "error", NULL), "retry": True};
    }
    return n if s == "pending" else {**n, "vars": {"count": b["scanned"]}};
}

# 409 MIGRATION_REQUIRED comes from servers that have not applied the promotions migration yet.
def getModeErrorKey(status: any, code: any = None) -> str {
    if status == 409 and code == "MIGRATION_REQUIRED" {
        return "settings.promotions.migrationRequired";
    }
    return "settings.promotions.forbidden" if status == 403 else "settings.promotions.saveFailed";
}

def:priv deltas(inbox: any, promo: any) -> dict[str, any] {
    return {
        k: v
        for (k, v) in [("inboxUnreadDelta", inbox), ("promotionsUnreadDelta", promo)]
        if v
    };
}

# Inbox rows count toward Inbox, and Promotions too when promotions in a mailbox that has it on;
# Promotions rows toward Promotions, and Inbox too in `show` mode, where they are listed in both.
def unreadDeltas(c: any, flip: any) -> any {
    if not flip or at(c, "folderId") {
        return NULL;
    }
    mode = at(c, "mode");
    on = bool(mode) and mode != "off";
    if c["folder"] == "inbox" {
        return deltas(flip, flip if on and at(c, "category") == "promotions" else 0);
    }
    return deltas(flip if mode == "show" else 0, flip)
        if c["folder"] == "promotions" and on
        else NULL;
}

def:priv pick(d: any) -> any {
    return (at(d, "inboxUnreadDelta", 0), at(d, "promotionsUnreadDelta", 0));
}

def mergeUnreadDeltas(a: any, b: any) -> any {
    if not a or not b {
        return b if not a else a;
    }
    ((i, p), (j, q)) = (pick(a), pick(b));
    return deltas(i + j, p + q);
}

def negateUnreadDeltas(d: any) -> any {
    return deltas(-pick(d)[0], -pick(d)[1]) if d else NULL;
}

type PromotionModeValue = any;
type BackfillState = any;
type UnreadDeltas = any;
