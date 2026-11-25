"""A whole percent between 0 and 100; anything unreadable shows as 0%."""
def formatReadRate(rate: any) -> str {
    if not globalThis.Number.isFinite(rate) {
        return "0%";
    }
    percent = globalThis.Math.min(100, globalThis.Math.max(0, globalThis.Math.round(rate)));
    return globalThis.String(percent) + "%";
}

"""What one row shows and offers. Only people with full access get the category control and the actions, matching the
server. Unsubscribing needs an unsubscribe route on the newest message and is not offered again once done, unless the
sender kept mailing ("still sending")."""
def getRowView(row: any, permission: any = None) -> dict[str, any] {
    can_change = canManagePromotions(permission);
    unsubscribed = row["unsubscribedAt"];
    still_sending = unsubscribed is not NULL and row["stillSending"];
    can_unsubscribe = row["canUnsubscribe"]
        and bool(row["latestMessageId"])
        and (unsubscribed is NULL or still_sending);
    actions = ["block", "trash"];
    if not can_change {
        actions = [];
    } elif can_unsubscribe {
        actions = ["unsubscribe", "unsubscribeTrash", "block", "trash"];
    }
    return {
        "canChange": can_change,
        "category": at(row, "categoryOverride", "auto"),
        "stillSending": still_sending,
        "unsubscribedOn": unsubscribed,
        "actions": actions,
    };
}

def categoryToApi(category: str) -> any {
    return NULL if category == "auto" else category;
}

"""After a category change: "Automatic" only clears the rule, the others report what was moved and what older mail was left."""
def categoryResultCopy(category: str, result: any) -> dict[str, any] {
    return {"key": "subscriptions.categoryCleared"}
        if category == "auto"
        else senderResultCopy(result);
}

"""Confirm text for "move to Trash" actions, or null when there is nothing to move. `willChange` is what this request
reaches (last 90 days, at most 500); everything else from the sender stays, and the text says how much."""
def trashConfirmCopy(action: str, preview: any) -> any {
    if preview["willChange"] <= 0 {
        return NULL;
    }
    stays = preview["count"] - preview["willChange"] + preview["olderLeft"];
    key = "subscriptions.trashConfirm"
        if action == "trash"
        else "subscriptions.unsubscribeTrashConfirm";
    copy = [{"key": key, "vars": {"count": preview["willChange"]}}];
    if stays > 0 {
        copy.append({"key": "subscriptions.leftBehind", "vars": {"count": stays}});
    }
    return copy;
}

"""What a real run did: the rows it changed and what of the sender is still where it was. Never "all"."""
def trashResultCopy(result: any) -> list[any] {
    copy = [
        {"key": "subscriptions.trashDone", "vars": {"count": result["changed"]}}
            if result["changed"] > 0
            else {"key": "subscriptions.trashNothing"},
    ];
    if result["remaining"] > 0 {
        copy.append({
            "key": "subscriptions.trashRemaining",
            "vars": {"remaining": result["remaining"]},
        });
    }
    return copy;
}

"""Where to load after a refetch: an emptied page (its last sender was trashed, blocked or moved) steps back one page."""
def pageBackOffset(given: any) -> any {
    (offset, size, total) = (given["offset"], given["pageSize"], given["total"]);
    if given["returned"] > 0 or offset <= 0 {
        return offset;
    }
    last_page = globalThis.Math.floor((total - 1) / size) * size if total > 0 else 0;
    return globalThis.Math.max(0, globalThis.Math.min(offset - size, last_page));
}

def getPager(given: any) -> dict[str, any] {
    (offset, count, total, size) = (
        given["offset"],
        given["count"],
        given["total"],
        given["pageSize"],
    );
    if total == 0 or count == 0 {
        return {"start": 0, "end": 0, "total": total, "prevOffset": NULL, "nextOffset": NULL};
    }
    end = offset + count;
    return {
        "start": offset + 1,
        "end": end,
        "total": total,
        "prevOffset": globalThis.Math.max(0, offset - size) if offset > 0 else NULL,
        "nextOffset": offset + size if end < total else NULL,
    };
}

"""Mailboxes the page can list: Promotions has to be on for them."""
def mailboxesWithPromotions(mailboxes: any, modes: any = None) -> list[any] {
    if nil(modes) {
        return [];
    }
    return [m for m in mailboxes if modes[m["id"]] and modes[m["id"]] != "off"];
}

"""Keeps the current choice, then the mailbox selected in the header, then the first one."""
def pickMailboxId(ids: any, current: any, selected: any = None) -> any {
    for wanted in [current, selected] {
        if wanted and wanted in ids {
            return wanted;
        }
    }
    return either(ids[0], NULL) if len(ids) else NULL;
}

"""Whole days between a timestamp and now; never negative."""
def daysSince(value: any, now: any) -> any {
    elapsed = now.getTime() - new(globalThis.Date, value).getTime();
    return globalThis.Math.max(0, globalThis.Math.floor(elapsed / 86400000));
}
