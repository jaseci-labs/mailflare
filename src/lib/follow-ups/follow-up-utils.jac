"""Reminder delays offered by the composer, in days after delivery."""
glob FOLLOW_UP_DAY_OPTIONS: any = [1, 3, 7],
     MAX_FOLLOW_UP_DAYS: int = 30;

glob:priv DAY_MS: int = 24 * 60 * 60 * 1000;

"""Accepts a whole number of days from a form or JSON body; anything else means no reminder."""
def parseFollowUpDays(value: any = None) -> any {
    days = globalThis.Number(value.strip()) if isinstance(value, str) else value;
    return days if globalThis.Number.isInteger(days) and 1 <= days <= MAX_FOLLOW_UP_DAYS else NULL;
}

def followUpDueAt(since: any, days: any) -> any {
    return new(globalThis.Date, since.getTime() + days * DAY_MS);
}

"""
Whether an inbound message answers the sent one: same mailbox and thread, and received after
the send. Replies are threaded by In-Reply-To/References, so a reply to any message in the
conversation counts.
"""
def isReplyTo(sent: any, candidate: any) -> bool {
    return candidate.direction == "inbound"
        and bool(sent.threadId)
        and candidate.threadId is sent.threadId
        and candidate.mailboxId is sent.mailboxId
        and candidate.createdAt.getTime() > sent.createdAt.getTime();
}
