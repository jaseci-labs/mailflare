glob CONTACT_AVATAR_CHANGED_EVENT: str = "mailflare:contact-avatar-changed";

def dispatchContactAvatarChanged(detail: any) {
    event = new(globalThis.CustomEvent, CONTACT_AVATAR_CHANGED_EVENT, record({"detail": detail}));
    globalThis.window.dispatchEvent(event);
}
