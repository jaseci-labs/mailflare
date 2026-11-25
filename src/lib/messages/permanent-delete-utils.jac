glob:priv FOLDER_LABEL_KEYS: dict[any, str] = {
    "trash": "navigation.trash",
    "spam": "navigation.spam",
};

"""The caller's translator, or English for callers without one (and tests)."""
def:priv translator(t: any) -> any {
    return defaultTranslator if t is None else t;
}

def getPermanentDeleteFolderLabel(folder: any, t: any = None) -> str {
    return translator(t)(FOLDER_LABEL_KEYS.get(folder));
}

"""Whether the folder being viewed offers "Delete forever" and "Empty …"."""
def supportsPermanentDelete(folder: any = None) -> bool {
    return folder in ["trash", "spam"];
}

def getEmptyFolderLabel(folder: any, t: any = None) -> str {
    return translator(t)("list.emptyFolder", {"folder": getPermanentDeleteFolderLabel(folder, t)});
}

def getPermanentDeleteConfirmText(count: any, t: any = None) -> str {
    return translator(t)("delete.confirm", {"count": count});
}

def getEmptyFolderConfirmText(folder: any, total: any = None, t: any = None) -> str {
    size = "single"
        if total == 1
        else ("multiple" if total and globalThis.Number(total) > 1 else "all");
    return translator(t)(
        f"empty.confirm.{size}",
        {"count": either(total, 0), "folder": getPermanentDeleteFolderLabel(folder, t)},
    );
}

"""Some of the requested messages were not in Trash or Spam any more, so the server kept them."""
obj PartialDeleteError(globalThis.Error) {
    has skipped: int;

    def init(skipped: int) {
        super.init("Some messages could not be deleted");
        self.skipped = skipped;
    }
}

async def throwIfDeleteSkipped(response: any, action: str) {
    if action != "delete" {
        return;
    }
    result = await response.json().catch(lambda (e: any) -> any { NULL });
    skipped = at(result, "skipped") if result else None;
    if not skipped {
        return;
    }
    globalThis.window.dispatchEvent(new(globalThis.Event, "mailflare:messages-changed"));
    raise PartialDeleteError(skipped);
}
