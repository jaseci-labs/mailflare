# Reminder delays offered by the composer, in days after delivery.
glob FOLLOW_UP_DAY_OPTIONS: any = [1, 3, 7],
     MAX_FOLLOW_UP_DAYS: int = 30;

# A whole number of days from a form or JSON body; anything else means no reminder.
def parseFollowUpDays(value: any = None) -> any {
    days = globalThis.Number(value.strip()) if isinstance(value, str) else value;
    return days if globalThis.Number.isInteger(days) and 1 <= days <= MAX_FOLLOW_UP_DAYS else NULL;
}

def followUpDueAt(since: any, days: any) -> any {
    return new(globalThis.Date, since.getTime() + days * 24 * 60 * 60 * 1000);
}

# An inbound message answers the sent one when it is in the same mailbox and thread and arrived
# later; replies thread by In-Reply-To/References, so a reply to any message in it counts.
def isReplyTo(sent: any, c: any) -> bool {
    same = bool(sent.threadId) and c.threadId is sent.threadId and c.mailboxId is sent.mailboxId;
    return c.direction == "inbound" and same and c.createdAt.getTime() > sent.createdAt.getTime();
}
