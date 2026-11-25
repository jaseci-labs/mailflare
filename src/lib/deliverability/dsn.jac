"""Reads the first 256 KiB of a returned message; real delivery reports are a few KB."""
glob MAX_DSN_BYTES: int = 256 * 1024;

"""Lower-cased name to value: continuation lines unfolded, the first value of each name kept."""
def:priv parse_headers(head: str) -> dict[str, any] {
    headers: dict[str, any] = {};
    # A line's trailing CR goes with the trimmed value.
    for line in sub(head, rx(r"\r?\n[ \t]+", "g"), " ").split("\n") {
        (colon, name) = (line.indexOf(":"), line.slice(0, line.indexOf(":")).trim().toLowerCase());
        if colon > 0 and name not in headers {
            headers[name] = line.slice(colon + 1).trim();
        }
    }
    return headers;
}

"""The headers and the body of a MIME part."""
def:priv split_part(text: any) -> tuple[dict[str, any], str] {
    found = rx(r"\r?\n\r?\n").exec(text);
    head = text.slice(0, found.index) if found else text;
    return (parse_headers(head), text.slice(found.index + len(found[0])) if found else "");
}

def:priv param(value: str, name: str) -> any {
    found = rx(name + r'\s*=\s*(?:"([^"]*)"|([^;\s]+))', "i").exec(value);
    return either(found[1], found[2]) if found else None;
}

"""A top-level multipart/report of type delivery-status (RFC 3464); null for any other message."""
def parseDeliveryStatus(raw: any) -> any {
    cut = raw.slice(0, MAX_DSN_BYTES) if raw.byteLength > MAX_DSN_BYTES else raw;
    (top, body) = split_part(new(globalThis.TextDecoder, "utf-8").decode(cut));
    kind = top.get("content-type", "");
    boundary = param(kind, "boundary");
    ok = rx(r"^multipart\/report", "i").test(kind) and not nil(param(kind, "report-type"));
    if not ok or param(kind, "report-type").toLowerCase() != "delivery-status" or not boundary {
        return NULL;
    }
    recipients: list[any] = [];
    original: any = NULL;
    for chunk in body.split(f"--{boundary}")[1:] {
        if chunk.startswith("--") {
            break;
        }
        (headers, content) = split_part(rx_sub(chunk, rx(r"^\r?\n"), ""));
        kind = headers.get("content-type", "").split(";")[0].trim().toLowerCase();
        if kind == "message/delivery-status" {
            groups = globalThis.String.prototype.split.call(content, rx(r"\r?\n\r?\n"));
            for fields in [parse_headers(g) for g in groups] {
                who: any = sub(fields.get("final-recipient", ""), rx(r"^[^;]*;\s*"), "").trim();
                if who {
                    action = fields.get("action", "").toLowerCase();
                    (status, why) = (fields.get("status", ""), fields.get("diagnostic-code", ""));
                    found = {"finalRecipient": who, "action": action, "status": status};
                    recipients.append({**found, "diagnostic": why});
                }
            }
        } elif kind in ["text/rfc822-headers", "message/rfc822"] {
            id: any = split_part(f"{content}\r\n\r\n")[0].get("message-id", "");
            id = sub(id, rx(r"^<|>$", "g"), "").trim();
            original = id if id and not original else original;
        }
    }
    return {"originalMessageId": original, "recipients": recipients} if recipients else NULL;
}
