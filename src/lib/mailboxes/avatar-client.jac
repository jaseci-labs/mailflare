glob MAILBOX_AVATAR_CHANGED_EVENT: str = "mailflare:mailbox-avatar-changed";

def dispatchMailboxAvatarChanged(mailboxId: any, url: any) {
    detail = record({"detail": record({"mailboxId": mailboxId, "url": url})});
    globalThis.window.dispatchEvent(
        new(globalThis.CustomEvent, MAILBOX_AVATAR_CHANGED_EVENT, detail)
    );
}
