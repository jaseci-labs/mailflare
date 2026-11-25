"""Every note shows who wrote it, so only its author may change the text.
A note whose author account is gone can no longer be edited."""
def canEditNote(authorUserId: any, userId: any) -> bool {
    return authorUserId is not NULL and authorUserId is userId;
}

"""The author may delete their note, and so may anyone with full access to the mailbox."""
def canDeleteNote(authorUserId: any, userId: any, canManageMailbox: any) -> any {
    return canManageMailbox or canEditNote(authorUserId, userId);
}
