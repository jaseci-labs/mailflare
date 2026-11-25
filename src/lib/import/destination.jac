glob:priv SYSTEM_SECTIONS: list[str] = ["inbox", "sent", "drafts", "archived", "spam", "trash"],
          # (direction, status) of each system section; anything else lands in the inbox.
          PLACEMENTS: dict[str, tuple[str, str]] = {
              "sent": ("outbound", "sent"),
              "drafts": ("outbound", "draft"),
              "archived": ("inbound", "archived"),
              "spam": ("inbound", "spam"),
              "trash": ("inbound", "trash"),
          };

glob DEFAULT_IMPORT_DESTINATION = "system:inbox";

def parseImportDestination(value: any = None) -> dict[str, str] {
    destination: str = value.trim()
        if isinstance(value, str) and value.trim()
        else DEFAULT_IMPORT_DESTINATION;
    if destination.startswith("folder:") {
        folderId: any = destination.removeprefix("folder:");
        if not folderId.trim() {
            raise new(globalThis.Error, "Import folder is required");
        }
        return {"type": "folder", "folderId": folderId.trim()};
    }
    section = destination.removeprefix("system:");
    if section in SYSTEM_SECTIONS {
        return {"type": "system", "section": section};
    }
    raise new(globalThis.Error, "Import destination is invalid");
}

def getImportMessagePlacement(destination: any) -> dict[str, any] {
    if destination["type"] == "folder" {
        return {"direction": "inbound", "status": "received", "folderId": destination["folderId"]};
    }
    (direction, status) = PLACEMENTS.get(destination["section"], ("inbound", "received"));
    return {"direction": direction, "status": status, "folderId": NULL};
}

def getImportMessageUserId(destination: any, currentUserId: str, mailboxUserId: str) -> str {
    mine = destination["type"] == "system" and destination["section"] in ["sent", "drafts"];
    return currentUserId if mine else mailboxUserId;
}
