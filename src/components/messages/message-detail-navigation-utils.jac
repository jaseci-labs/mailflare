glob:priv KEY: str = "mailflare-navigation-opened-unread";

def rememberOpenedUnreadMessage(messageId: any) {
    try {
        globalThis.sessionStorage.setItem(KEY, messageId);
    } except Exception {}  # Navigation remains available when browser storage is disabled.
}

def takeOpenedUnreadMessage -> any {
    try {
        id = globalThis.sessionStorage.getItem(KEY);
        globalThis.sessionStorage.removeItem(KEY);
        return id;
    } except Exception {
        return NULL;
    }
}

"""The message auto-advance opens once `currentId` leaves the list: the one below it (older), else
the one above. List order, not the arrows' unread-first order, so it lands on the neighbour you see."""
def getAutoAdvanceId(entries: any, currentId: any) -> any {
    ids = [e["id"] for e in entries];
    i = ids.index(currentId) if currentId in ids else -9;
    near = [ids[j] for j in [i + 1, i - 1] if 0 <= j < len(ids) and not nil(ids[j])];
    return either(first(near), NULL);
}

def getMessageDetailNavigationState(entries: any, currentId: any) -> any {
    unread = [e for e in entries if e["unread"]];
    ids = [e["id"] for e in unread + [e for e in entries if not e["unread"]]];
    i = ids.index(currentId) if currentId in ids else -1;
    return {
        "previousId": ids[i - 1] if i > 0 else NULL,
        "nextId": either(ids[i + 1], NULL) if 0 <= i < len(ids) - 1 else NULL,
        "unreadOrder": i + 1 if 0 <= i < len(unread) else 0,
        "totalUnread": len(unread),
    };
}
