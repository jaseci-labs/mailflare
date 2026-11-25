# Precedence values that mark mass mail (RFC 2076 and common practice).
glob:priv BULK_PRECEDENCE: list[str] = ["bulk", "list", "junk"];

# Headers that only mass-mailing tools set. Anything an ESP adds to every message it relays,
# transactional receipts included (`X-SES-Outgoing`, `X-SG-EID`, `X-Mailgun-Tag`, `X-Mailer`), is
# deliberately left out, so a password reset or order receipt that passes through the same
# provider as a newsletter is not caught.
glob:priv CAMPAIGN_HEADERS: list[str] = ["x-campaign", "x-campaign-id", "x-campaignid"];

"""A header's trimmed value; names come from different intake paths, so the lookup ignores case."""
def getMailHeader(headers: any, name: str) -> str {
    if not headers {
        return "";
    }
    for (key, value) in entries(headers) {
        label: any = key;
        if label.toLowerCase() == name {
            return value.trim() if isinstance(value, str) else "";
        }
    }
    return "";
}

def:priv precedence_of(headers: any) -> str {
    value: any = getMailHeader(headers, "precedence");
    return value.toLowerCase();
}

"""`List-Id` present, or `Precedence: bulk|list|junk`. The part auto-reply suppression uses."""
def hasListOrBulkPrecedence(headers: any) -> bool {
    return bool(getMailHeader(headers, "list-id")) or precedence_of(headers) in BULK_PRECEDENCE;
}

"""Decides whether a message is newsletter, promotional or mailing-list mail from its headers alone.

It can so run at SMTP time, before the body is parsed. `bulk` is true when any of these is present:
- `List-Unsubscribe`: RFC 2369 unsubscribe link, required of bulk senders by Gmail and Yahoo.
- `List-Id`: RFC 2919 mailing-list identifier.
- `Precedence: bulk`, `list` or `junk`.
- `X-Campaign` or `X-Campaign-ID`: campaign tags set by marketing tools.

`Feedback-ID` is recorded in `reasons` when one of those is also present, but never decides on
its own: SES, Postmark and Google stamp it on transactional mail (one-time codes, receipts) as
well as on campaigns.

Not bulk on their own: `Feedback-ID`, `Auto-Submitted` (auto-replies and notifications are
machine mail, not promotions), `X-Auto-Response-Suppress`, and per-message ESP trace headers.
A plain personal message carries none of the above. Some transactional receipts do (Shopify and
Stripe often add `List-Unsubscribe`), so they can match; rules that act on this result must stay
non-destructive.

Contract for callers: `headers` is the lower- or mixed-case header map of the inbound message
(the `headers` of an inbound queue payload). Missing headers mean `bulk: false`, never an error.
The result is advisory classification: it changes no state. `reasons` names the signals that
fired, as `header` or `header: value`, in a stable order.
"""
def isBulkMail(headers: any) -> dict[str, any] {
    reasons = [name for name in ["list-unsubscribe", "list-id"] if getMailHeader(headers, name)];
    precedence = precedence_of(headers);
    if precedence in BULK_PRECEDENCE {
        reasons.append(f"precedence: {precedence}");
    }
    reasons += [name for name in CAMPAIGN_HEADERS if getMailHeader(headers, name)];
    bulk = len(reasons) > 0;
    if bulk and getMailHeader(headers, "feedback-id") {
        reasons.append("feedback-id");
    }
    return {"bulk": bulk, "reasons": reasons};
}

"""Classifies one message for the Promotions view from its headers alone.

Strong signals are exactly `isBulkMail`'s, so routing rules and Promotions never disagree about
what is bulk. ESP trace headers (`X-SES-Outgoing`, `X-SG-EID`, ...) and a footer unsubscribe link
are deliberately not signals: receipts and password resets carry both.

`kind` is `list` for a discussion list (`List-Post`, or `Precedence: list` with `List-Id`),
`marketing` for other bulk mail, null when not bulk; `signals` are the header names alone.
"""
def detectBulkMail(headers: any) -> dict[str, any] {
    verdict = isBulkMail(headers);
    discussion_list = bool(getMailHeader(headers, "list-post"))
        or (bool(getMailHeader(headers, "list-id")) and precedence_of(headers) == "list");
    kind = NULL if not verdict["bulk"] else ("list" if discussion_list else "marketing");
    return {
        "bulk": verdict["bulk"],
        "kind": kind,
        "signals": [reason.split(":")[0] for reason in verdict["reasons"]],
    };
}

# Types that TypeScript modules still import by name.
type MailHeaders = dict[str, any];

type BulkMailVerdict = dict[str, any];
