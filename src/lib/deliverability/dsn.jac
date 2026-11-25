"""Reads the first 256 KiB of a returned message; real delivery reports are a few KB."""
glob MAX_DSN_BYTES: int = 256 * 1024;

glob:priv BLANK_LINE: any = rx(r"\r?\n\r?\n"),
          FOLD: any = rx(r"\r?\n[ \t]+", "g"),
          LINE_END: any = rx(r"\r?\n"),
          LEADING_LINE_END: any = rx(r"^\r?\n"),
          ADDRESS_TYPE: any = rx(r"^[^;]*;\s*"),
          ANGLES: any = rx(r"^<|>$", "g"),
          REPORT: any = rx(r"^multipart\/report", "i");

def:priv rx_split(s: str, regex: any) -> list[any] {
    return globalThis.String.prototype.split.call(s, regex);
}

"""A header block as lower-cased name to value: continuation lines unfolded, the first value of each name kept."""
def:priv parse_headers(head: str) -> dict[str, any] {
    headers: dict[str, any] = {};
    for line in rx_split(rx_sub(head, FOLD, " "), LINE_END) {
        colon = line.indexOf(":");
        if colon <= 0 {
            continue;
        }
        name = line.slice(0, colon).trim().toLowerCase();
        if name not in headers {
            headers[name] = line.slice(colon + 1).trim();
        }
    }
    return headers;
}

"""The headers and the body of a MIME part."""
def:priv split_part(text: any) -> tuple[dict[str, any], str] {
    found = BLANK_LINE.exec(text);
    if not found {
        return (parse_headers(text), "");
    }
    return (parse_headers(text.slice(0, found.index)), text.slice(found.index + len(found[0])));
}

def:priv content_type_param(value: str, name: str) -> any {
    found = rx(name + r'\s*=\s*(?:"([^"]*)"|([^;\s]+))', "i").exec(value);
    return either(found[1], found[2]) if found else None;
}

"""A top-level multipart/report of type delivery-status (RFC 3464); null for any other message."""
def parseDeliveryStatus(raw: any) -> any {
    text = new(globalThis.TextDecoder, "utf-8").decode(
        raw.slice(0, MAX_DSN_BYTES) if raw.byteLength > MAX_DSN_BYTES else raw
    );
    (top, body) = split_part(text);
    content_type = top.get("content-type", "");
    report_type = content_type_param(content_type, "report-type");
    boundary = content_type_param(content_type, "boundary");
    if not REPORT.test(content_type)
        or nil(report_type)
        or report_type.toLowerCase() != "delivery-status"
        or not boundary
    {
        return NULL;
    }
    recipients: list[any] = [];
    original: any = NULL;
    for chunk in body.split(f"--{boundary}")[1:] {
        if chunk.startswith("--") {
            break;
        }
        (headers, content) = split_part(rx_sub(chunk, LEADING_LINE_END, ""));
        kind = headers.get("content-type", "").split(";")[0].trim().toLowerCase();
        if kind == "message/delivery-status" {
            for group in rx_split(content, BLANK_LINE) {
                fields = parse_headers(group);
                final: any = rx_sub(fields.get("final-recipient", ""), ADDRESS_TYPE, "");
                if not final.trim() {
                    continue;
                }
                recipients.append({
                    "finalRecipient": final.trim(),
                    "action": fields.get("action", "").toLowerCase(),
                    "status": fields.get("status", ""),
                    "diagnostic": fields.get("diagnostic-code", ""),
                });
            }
        } elif kind in ["text/rfc822-headers", "message/rfc822"] {
            id: any = rx_sub(split_part(f"{content}\r\n\r\n")[0].get("message-id", ""), ANGLES, "");
            if id.trim() and not original {
                original = id.trim();
            }
        }
    }
    return {"originalMessageId": original, "recipients": recipients} if recipients else NULL;
}
