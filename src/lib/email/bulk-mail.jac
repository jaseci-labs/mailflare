# BULK_PRECEDENCE: Precedence values that mark mass mail (RFC 2076 and common practice).
# CAMPAIGN_HEADERS: set only by mass-mailing tools. Headers an ESP adds to everything it relays
# (`X-SES-Outgoing`, `X-SG-EID`, `X-Mailgun-Tag`, `X-Mailer`) are left out on purpose, so a
# password reset or receipt sent through a newsletter's provider is not caught.
glob:priv BULK_PRECEDENCE: list[str] = ["bulk", "list", "junk"],
          CAMPAIGN_HEADERS: list[str] = ["x-campaign", "x-campaign-id", "x-campaignid"];
type MailHeaders = any;
type BulkMailVerdict = any;

# A header's trimmed value; names come from different intake paths, so the lookup ignores case.
def getMailHeader(headers: any, name: str) -> str {
    for (key, value) in entries(headers) if headers else [] {
        if globalThis.String(key).toLowerCase() == name {
            return value.trim() if isinstance(value, str) else "";
        }
    }
    return "";
}

def:priv precedence_of(headers: any) -> str {
    return globalThis.String(getMailHeader(headers, "precedence")).toLowerCase();
}

# `List-Id` present, or `Precedence: bulk|list|junk`. The part auto-reply suppression uses.
def hasListOrBulkPrecedence(headers: any) -> bool {
    return bool(getMailHeader(headers, "list-id")) or precedence_of(headers) in BULK_PRECEDENCE;
}

# Newsletter, promotional or mailing-list mail, from headers alone (so it runs at SMTP time).
# `bulk` when any of these is present: `List-Unsubscribe` (RFC 2369, required of bulk senders by
# Gmail and Yahoo), `List-Id` (RFC 2919), `Precedence: bulk|list|junk`, `X-Campaign`/`X-Campaign-ID`.
# `Feedback-ID` joins `reasons` only beside one of those: SES, Postmark and Google stamp it on
# transactional mail too. `Auto-Submitted`, `X-Auto-Response-Suppress` and ESP trace headers never
# count. Some receipts carry `List-Unsubscribe` (Shopify, Stripe), so rules acting on this must
# stay non-destructive. Missing headers mean `bulk: false`, never an error; it changes no state.
# `reasons` names the signals that fired, as `header` or `header: value`, in a stable order.
def isBulkMail(headers: any) -> any {
    reasons = [name for name in ["list-unsubscribe", "list-id"] if getMailHeader(headers, name)];
    precedence = precedence_of(headers);
    reasons += [f"precedence: {precedence}"] if precedence in BULK_PRECEDENCE else [];
    reasons += [name for name in CAMPAIGN_HEADERS if getMailHeader(headers, name)];
    reasons += ["feedback-id"] if reasons and getMailHeader(headers, "feedback-id") else [];
    return record({"bulk": len(reasons) > 0, "reasons": reasons});
}

# Classifies one message for the Promotions view on exactly `isBulkMail`'s signals, so routing rules
# and Promotions never disagree (a footer unsubscribe link is not a signal: receipts carry one).
# `kind` is `list` for a discussion list (`List-Post`, or `Precedence: list` with `List-Id`),
# `marketing` for other bulk mail, null when not bulk; `signals` are the header names alone.
def detectBulkMail(headers: any) -> any {
    verdict = isBulkMail(headers);
    listed = bool(getMailHeader(headers, "list-id")) and precedence_of(headers) == "list";
    discussion = bool(getMailHeader(headers, "list-post")) or listed;
    kind = ("list" if discussion else "marketing") if verdict["bulk"] else NULL;
    signals = [reason.split(":")[0] for reason in verdict["reasons"]];
    return record({"bulk": verdict["bulk"], "kind": kind, "signals": signals});
}
