"""Client-safe: used by the message page as well as the server-side invitation code."""

# Calendar files larger than this are not read as invitations.
glob MAX_INVITE_BYTES: int = 256 * 1024;

def isInviteAttachment(attachment: any) -> bool {
    return rx(r"^text\/calendar", "i").test(attachment["type"])
        or rx(r"\.ics$", "i").test(attachment["filename"]);
}

def findInviteAttachment(attachments: any) -> any {
    return attachments.find(isInviteAttachment);
}
