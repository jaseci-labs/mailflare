# Names the TypeScript side imports as types. A MessagesChangedDetail is one of:
#   kind "read" | "patch" | "removed" | "restored", with messageIds, read, and per-message
#   `patches` when a batch has mixed values;
#   threadTargets: absolute grouped unread targets, applied rather than incremented, so a
#   repeated desired value and a second event are both no-ops;
#   the membership mutation: optimistic events carry `action`, folderId and snoozedUntil so a
#   mounted row can derive its own target, committed events carry the applied `states`;
#   localOnly: optimistic facts stay in this tab; realtime: the event came from another tab.
type MessageFieldPatch = any;
type MessageMembershipState = any;
type MessagesChangedDetail = any;

glob MESSAGES_CHANGED_EVENT: str = "mailflare:messages-changed";

def dispatchMessagesChanged(detail: any = None) {
    globalThis.window.dispatchEvent(
        new(globalThis.CustomEvent, MESSAGES_CHANGED_EVENT, record({"detail": detail}))
    );
}

"""A property of a record that may lack it: undefined when missing, null kept as null."""
def:priv opt(o: any, k: str) -> any {
    return o.get(k) if isinstance(o, dict) else getattr(o, k, None);
}

def getMessagesChangedDetail(event: any) -> any {
    return opt(event, "detail");
}

def isReadOnlyChange(event: any) -> bool {
    detail = opt(event, "detail");
    kind = opt(detail, "kind") if detail else None;
    if kind != "patch" {
        return kind == "read";
    }
    patches = at(detail, "patches", []);
    return len(patches) > 0
        and all([opt(p, "read") is not None and opt(p, "starred") is None for p in patches]);
}
