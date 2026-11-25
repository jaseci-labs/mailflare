glob:priv SUFFIX: dict[str, str] = {
    "preview": "?preview=1",
    "risk": "?risk=1",
    "download": "?download=1",
    "acknowledged-download": "?download=1&acknowledge=1",
};

def getAttachmentFileUrl(messageId: any, attachmentId: any, mode: any = None) -> str {
    suffix = globalThis.String(SUFFIX.get("download" if mode is None else mode));
    return f"/api/messages/{messageId}/attachments/{attachmentId}{suffix}";
}

def getAttachmentPreviewKind(attachment: any) -> str {
    t: any = attachment["type"];
    media = t.split("/")[0] if "/" in t else "";
    if t == "application/pdf"
        or media in ["audio", "video"]
        or media == "image" and t != "image/svg+xml"
    {
        return "pdf" if t == "application/pdf" else media;
    }
    text = t.startswith("text/plain") or t in ["application/json", "application/xml", "text/csv"];
    return "text" if text else "unsupported";
}
