glob CONTACT_AVATAR_CHANGED_EVENT: str = "mailflare:contact-avatar-changed";

def dispatchContactAvatarChanged(detail: any) {
    globalThis.window.dispatchEvent(
        new(globalThis.CustomEvent, CONTACT_AVATAR_CHANGED_EVENT, record({"detail": detail}))
    );
}
