glob SUPPRESSED_RECIPIENT_CODE: str = "SUPPRESSED_RECIPIENT",
     MAX_SUPPRESSION_DETAIL: int = 300;

glob:priv ADDRESS: any = rx(r"^[^\s@<>]+@[^\s@<>]+$");

# Types the TypeScript callers name.
type SuppressionMode = str;
type SuppressionReason = str;
type SuppressionSource = str;
type SuppressionEntry = dict[str, any];
type SuppressionEvent = dict[str, any];

"""Thrown before anything is stored or sent when a recipient is on the sending domain's suppression list."""
obj SuppressedRecipientError(globalThis.Error) {
    has code: str = SUPPRESSED_RECIPIENT_CODE,
        addresses: any = None;

    def init(addresses: any) {
        super.init(f"These addresses bounced or reported spam: {', '.join(addresses)}");
        self.code = SUPPRESSED_RECIPIENT_CODE;
        self.addresses = addresses;
    }
}

"""Body of the 422 that /api/send and /api/v1/send answer with."""
def suppressedRecipientBody(error: any) -> dict[str, any] {
    return {"error": error.message, "code": error.code, "addresses": error.addresses};
}

"""
JMAP EmailSubmission/set `notCreated` entry (RFC 8621 section 7.5). `recipientHeaders` are the
client's To/Cc/Bcc values: the addresses are echoed the way the client wrote them, not lower-cased.
"""
def suppressedSubmissionError(error: any, recipientHeaders: any = None) -> dict[str, any] {
    written: dict[str, str] = {};
    for header in either(recipientHeaders, []) {
        for recipient in splitEmailAddressList(None if nil(header) else header) {
            address: any = getEmailAddress(recipient);
            written.setdefault(address.trim().toLowerCase(), address.trim());
        }
    }
    invalid = [written.get(address, address) for address in error.addresses];
    return {
        "type": "invalidRecipients",
        "description": SuppressedRecipientError(invalid).message,
        "invalidRecipients": invalid,
    };
}

"""Bare lower-case address, or null for anything that is not one."""
def cleanAddress(value: any = None) -> any {
    if not isinstance(value, str) {
        return NULL;
    }
    address = normalizeEmailAddress(value);
    return address if ADDRESS.test(address) else NULL;
}

def addressDomain(address: str) -> str {
    return address.rsplit("@", 1)[-1].lower();
}

def:priv truncate(value: any) -> any {
    return value.trim().slice(0, MAX_SUPPRESSION_DETAIL)
        if isinstance(value, str) and value.trim()
        else None;
}

"""Splits header-style recipients into those still allowed (original entries kept) and the suppressed bare addresses."""
def filterSuppressed(recipients: any, suppressed: any) -> dict[str, list[str]] {
    allowed: list[str] = [];
    dropped: list[str] = [];
    for recipient in recipients {
        address = normalizeEmailAddress(recipient);
        if not suppressed.has(address) {
            allowed.append(recipient.trim());
        } elif address not in dropped {
            dropped.append(address);
        }
    }
    return {"allowed": allowed, "suppressed": dropped};
}

"""One entry per distinct valid address of `addresses`."""
def:priv to_entries(
    addresses: any, reason: str, detail: any = None, unconfirmed: bool = False
) -> list[any] {
    if not globalThis.Array.isArray(addresses) {
        return [];
    }
    found: dict[str, any] = {};
    for value in addresses {
        email = cleanAddress(value);
        if email and email not in found {
            found[email] = {"email": email, "reason": reason};
            if detail {
                found[email]["detail"] = detail;
            }
            if unconfirmed {
                found[email]["unconfirmed"] = True;
            }
        }
    }
    return list(found.values());
}

"""True of a JavaScript object that is not an array."""
def:priv is_object(value: any) -> bool {
    return globalThis.Object(value) is value
        and not callable(value)
        and not globalThis.Array.isArray(value);
}

"""
Resend `email.bounced` / `email.complained`. Resend documents `data.bounce.type` as
`Permanent` or `Temporary`; older material says `Transient`, so both soft types are
skipped and a bounce without a type counts as permanent (the event itself means the
receiving server permanently rejected the message).

The payload has `to` (every recipient of the message) but no field naming which one bounced or
complained. With one recipient the event is unambiguous; with several, naming all of them would let
one bad address block the rest, so those entries are stored unconfirmed and are not enforced.
"""
def mapResendEvent(body: any = None) -> any {
    if not is_object(body) or not is_object(at(body, "data")) {
        return NULL;
    }
    data = body["data"];
    sender = cleanAddress(data["from"]);
    if not sender {
        return NULL;
    }
    to = data["to"];
    ambiguous = globalThis.Array.isArray(to)
        and new(
            globalThis.Set,
            [(value.trim().toLowerCase() if isinstance(value, str) else value) for value in to],
        ).size
            > 1;
    found: list[any] = [];
    if body["type"] == "email.complained" {
        found = to_entries(to, "complaint", None, ambiguous);
    } elif body["type"] == "email.bounced" {
        bounce = data["bounce"] if is_object(data["bounce"]) else {};
        kind = at(bounce, "type");
        if isinstance(kind, str) and kind.trim().toLowerCase() in ["transient", "temporary"] {
            return NULL;
        }
        found = to_entries(to, "hard_bounce", truncate(at(bounce, "message")), ambiguous);
    }
    return {"sender": sender, "entries": found} if found else NULL;
}

"""SES feedback delivered through SNS: permanent bounces and complaints only."""
def mapSesNotification(message: str) -> any {
    try {
        parsed = globalThis.JSON.parse(message);
    } except Exception {
        return NULL;
    }
    if not is_object(parsed) or not is_object(parsed["mail"]) {
        return NULL;
    }
    sender = cleanAddress(parsed["mail"]["source"]);
    if not sender {
        return NULL;
    }
    (bounce, complaint) = (parsed["bounce"], parsed["complaint"]);
    found: list[any] = [];
    if parsed["notificationType"] == "Bounce"
        and is_object(bounce)
        and bounce["bounceType"] == "Permanent"
        and globalThis.Array.isArray(bounce["bouncedRecipients"])
    {
        for recipient in bounce["bouncedRecipients"] {
            if is_object(recipient) {
                found += to_entries(
                    [recipient["emailAddress"]],
                    "hard_bounce",
                    truncate(recipient["diagnosticCode"]),
                );
            }
        }
    } elif parsed["notificationType"] == "Complaint"
        and is_object(complaint)
        and globalThis.Array.isArray(complaint["complainedRecipients"])
    {
        for recipient in complaint["complainedRecipients"] {
            if is_object(recipient) {
                found += to_entries([recipient["emailAddress"]], "complaint");
            }
        }
    }
    return {"sender": sender, "entries": found} if found else NULL;
}
