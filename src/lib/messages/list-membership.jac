# The fields that decide which folder lists still contain a message.
type MessageMembershipFields = any;

# Message lists read these on every render: records are JavaScript objects or Jac dicts, read
# with `get` (a direct JavaScript call) rather than Jac's dynamic attribute and item access.

# `o.k` of a JavaScript object or a Jac dict.
def:priv get(o: any, k: str) -> any {
    return o.get(k) if isinstance(o, dict) else globalThis.Reflect.get(o, k);
}

def:priv snoozed_at(value: any, now: any) -> bool {
    if not value {
        return False;
    }
    time: float = globalThis.Date.parse(value);
    return bool(globalThis.Number.isFinite(time)) and time > now;
}

# Mirrors the server's list filters in `src/app/api/messages/route.ts`: a paginated list only
# contains rows whose current state matches its query.
def messageMatchesFolder(state: any, folder: str, folderId: any = None, now: any = None) -> any {
    status = get(state, "status");
    if folderId {
        # A custom folder query keeps status=received but skips the inbox folder/snooze branch,
        # so snoozed messages stay in the folder.
        return status == "received" and get(state, "folderId") is folderId;
    }
    if folder == "starred" {
        return get(state, "starred");
    }
    if folder == "inbox" or folder == "promotions" or folder == "snoozed" {
        # Inbox ignores the category on purpose: the promotions mode is not known here, so a
        # promotion restored to Inbox in a "separate" mailbox may show in a cached Inbox list
        # until the next refetch.
        if status != "received" or not nil(get(state, "folderId")) {
            return False;
        }
        time = globalThis.Date.now() if now is None else now;
        snoozed = snoozed_at(get(state, "snoozedUntil"), time);
        if folder == "snoozed" {
            return snoozed;
        }
        return not snoozed and (folder == "inbox" or get(state, "category") == "promotions");
    }
    if folder == "sent" {
        return status == "sent";
    }
    if folder == "scheduled" {
        return status == "queued";
    }
    if folder == "drafts" {
        return status == "draft";
    }
    return status == folder;
}

# `search.get(k)` with the `get` read once, as JavaScript calls it on whatever `search` is.
def:priv param(read: any, search: any, k: str) -> any {
    return globalThis.Function.prototype.call.call(read, search, k);
}

def:priv folder_of(folder: str) -> any {
    out: any = globalThis.Object();
    globalThis.Reflect.set(out, "folder", folder);
    return out;
}

# Reads the list identity back from the request key, so cache ingress can apply membership
# without the hook passing folder/folderId through every call.
def getListMembershipContext(params: any) -> any {
    search: any = new(globalThis.URLSearchParams, params) if isinstance(params, str) else params;
    read: any = globalThis.Reflect.get(search, "get");
    folderId = param(read, search, "folderId");
    if folderId {
        out: any = folder_of("inbox");
        globalThis.Reflect.set(out, "folderId", folderId);
        return out;
    }
    if param(read, search, "starred") == "true" {
        return folder_of("starred");
    }
    if param(read, search, "snoozed") == "true" {
        return folder_of("snoozed");
    }
    if param(read, search, "scheduled") == "true" {
        return folder_of("scheduled");
    }
    status = param(read, search, "status");
    direction = param(read, search, "direction");
    if direction == "inbound" and status == "received" {
        promotions = param(read, search, "category") == "promotions";
        return folder_of("promotions" if promotions else "inbox");
    }
    if direction == "outbound" and status == "sent" {
        return folder_of("sent");
    }
    if direction == "outbound" and status == "draft" {
        return folder_of("drafts");
    }
    if status == "archived" or status == "trash" or status == "spam" {
        return folder_of(status);
    }
    return NULL;
}

# Tombstones survive pagination: a row moved from page 2 returns to the same list even if
# backfill changed the offset before the undo completes.
def getListMembershipKey(params: any) -> str {
    text = params if isinstance(params, str) else params.toString();
    search: any = new(globalThis.URLSearchParams, text);
    globalThis.URLSearchParams.prototype.delete.call(search, "offset");
    globalThis.URLSearchParams.prototype.delete.call(search, "limit");
    return globalThis.URLSearchParams.prototype.toString.call(search);
}
