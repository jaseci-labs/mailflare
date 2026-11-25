glob MESSAGE_DRAG_MIME: str = "application/x-mailflare-message-ids";

def setMessageDragData(dataTransfer: any, payload: any) {
    dataTransfer.effectAllowed = "move";
    dataTransfer.setData(MESSAGE_DRAG_MIME, globalThis.JSON.stringify(payload));
    dataTransfer.setData("text/plain", payload.messageIds.join(","));
}

def getMessageDragData(dataTransfer: any) -> any {
    raw = dataTransfer.getData(MESSAGE_DRAG_MIME);
    if not raw {
        return NULL;
    }
    try {
        ids: any = at(globalThis.JSON.parse(raw), "messageIds", []).filter(globalThis.Boolean);
        return {"messageIds": ids} if ids.length > 0 else NULL;
    } except Exception {
        return NULL;
    }
}
