glob PROFILE_AVATAR_CHANGED_EVENT: str = "mailflare:profile-avatar-changed";

def getProfileAvatarUrl -> str {
    return f"/api/profile/avatar?v={globalThis.Date.now()}";
}

def dispatchProfileAvatarChanged(url: any) {
    detail = record({"detail": record({"url": url})});
    globalThis.window.dispatchEvent(
        new(globalThis.CustomEvent, PROFILE_AVATAR_CHANGED_EVENT, detail)
    );
}
