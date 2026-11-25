glob:priv FOLDED: any = rx(r"\r?\n[ \t]+", "g"),
          STATUS: any = rx(r"^Status:[ \t]*(.*)$", "im"),
          SPAM_FLAG: any = rx(r"^X-Spam-Flag:[ \t]*yes\b", "im");

"""The header block (at most 64 KiB) as text, folded lines joined."""
def:priv read_headers(raw: any) -> str {
    data = new(globalThis.Uint8Array, raw);
    end = globalThis.Math.min(data.length, 64 * 1024);
    for index in range(end - 1) {
        if data[index] == 10
            and (data[index + 1] == 10 or (data[index + 1] == 13 and data[index + 2] == 10))
        {
            end = index;
            break;
        }
    }
    return rx_sub(new(globalThis.TextDecoder).decode(data.subarray(0, end)), FOLDED, " ");
}

"""Exports carry their own state: mbox `Status`, Gmail labels, spam-filter verdicts.

Used where the upload gave no per-message flags. `section` is set only when the
message itself says it belongs in spam or trash.
"""
def getImportMessageHints(raw: any) -> dict[str, any] {
    hints: dict[str, any] = {};
    headers = read_headers(raw);
    status = STATUS.exec(headers);
    if status {
        hints["read"] = "R" in status[1].toUpperCase();
    }
    labels = parseGmailLabels(new(globalThis.Uint8Array, raw));
    if len(labels) {
        placement = mapGmailLabels(labels, record({"folders": False}));
        hints["read"] = placement.read;
        hints["starred"] = placement.starred;
        destination = placement.destination;
        if destination.type == "system" and destination.section in ["spam", "trash"] {
            hints["section"] = destination.section;
        }
    }
    if "section" not in hints and SPAM_FLAG.test(headers) {
        hints["section"] = "spam";
    }
    return hints;
}

"""A hint only refines the default destination; a section or folder the user picked is kept."""
def applyImportHints(destination: any, hints: any) -> any {
    section = at(hints, "section");
    if section and destination["type"] == "system" and destination["section"] == "inbox" {
        return {"type": "system", "section": section};
    }
    return destination;
}
