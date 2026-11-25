glob PROFILE_NAME_CHANGED_EVENT: str = "mailflare:profile-name-changed";

def dispatchProfileNameChanged(name: any) {
    detail = record({"detail": record({"name": name})});
    globalThis.window.dispatchEvent(
        new(globalThis.CustomEvent, PROFILE_NAME_CHANGED_EVENT, detail)
    );
}
