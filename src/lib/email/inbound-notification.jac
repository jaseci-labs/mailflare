"""The realtime and push payload for a stored inbound message.

The contact row may carry the first name ever learned for a shared address, so the label is
resolved from this message's own From header first.
"""
def buildNewMessageNotification(message: any) -> any {
    note = {
        "type": "new_message",
        "messageId": message["messageId"],
        "mailboxId": message["mailboxId"],
        "from": message["fromAddr"],
        "fromName": getPartyDisplayName(message["fromAddr"], message["contact"]),
        "subject": message["subject"],
    };
    if at(message, "category") {
        note["category"] = message["category"];
    }
    return record(note);
}
