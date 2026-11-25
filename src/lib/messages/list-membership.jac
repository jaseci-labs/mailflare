# A name the TypeScript side imports as a type: the fields that decide which folder lists
# still contain a message.
type MessageMembershipFields = any;

glob:priv STATUS_OF: dict[str, str] = {"sent": "sent", "scheduled": "queued", "drafts": "draft"},
          # (folder, the query parameters that name it); the first match wins
          LISTS: list[tuple[str, dict[str, str]]] = [
              ("starred", {"starred": "true"}),
              ("snoozed", {"snoozed": "true"}),
              ("scheduled", {"scheduled": "true"}),
              (
                  "promotions",
                  {"direction": "inbound", "status": "received", "category": "promotions"},
              ),
              ("inbox", {"direction": "inbound", "status": "received"}),
              ("sent", {"direction": "outbound", "status": "sent"}),
              ("drafts", {"direction": "outbound", "status": "draft"}),
              ("archived", {"status": "archived"}),
              ("trash", {"status": "trash"}),
              ("spam", {"status": "spam"}),
          ];

def:priv snoozed_at(value: any, now: any) -> bool {
    if not value {
        return False;
    }
    time = globalThis.Date.parse(value);
    return globalThis.Number.isFinite(time) and time > now;
}

"""
Mirrors the server's list filters in `src/app/api/messages/route.ts`.
A paginated list only contains rows whose current state matches its query.
"""
def messageMatchesFolder(state: any, folder: str, folderId: any = None, now: any = None) -> any {
    status = at(state, "status");
    if folderId {
        # A custom folder query keeps status=received but skips the inbox
        # folder/snooze branch, so snoozed messages stay in the folder.
        return status == "received" and at(state, "folderId") is folderId;
    }
    if folder == "starred" {
        return state["starred"];
    }
    if folder in ["inbox", "promotions", "snoozed"] {
        # Inbox membership ignores the category on purpose: the mailbox's promotions mode is not
        # known here, so a promotion restored to Inbox in a "separate" mailbox may show in a
        # cached Inbox list until the next refetch.
        snoozed = snoozed_at(
            at(state, "snoozedUntil"), globalThis.Date.now() if now is None else now
        );
        return status == "received"
            and nil(at(state, "folderId"))
            and snoozed == (folder == "snoozed")
            and (folder != "promotions" or at(state, "category") == "promotions");
    }
    return status == STATUS_OF.get(folder, folder);
}

"""
Reads the list identity back from the request key so cache ingress can apply
membership without the hook passing folder/folderId through every call.
"""
def getListMembershipContext(params: any) -> any {
    search = new(globalThis.URLSearchParams, params) if isinstance(params, str) else params;
    folderId = search.get("folderId");
    if folderId {
        return {"folder": "inbox", "folderId": folderId};
    }
    for (folder, query) in LISTS {
        if all([search.get(k) == v for (k, v) in query.items()]) {
            return {"folder": folder};
        }
    }
    return NULL;
}

"""
Tombstones survive pagination: a row moved from page 2 should return to the
same list even if backfill changed the offset before the undo completes.
"""
def getListMembershipKey(params: any) -> str {
    search = new(
        globalThis.URLSearchParams, params if isinstance(params, str) else params.toString()
    );
    search.delete("offset");
    search.delete("limit");
    return search.toString();
}
