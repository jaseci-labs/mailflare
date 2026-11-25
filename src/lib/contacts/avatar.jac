def contactAvatarKeyFor(userId: str, email: str) -> str {
    return f"contact-avatars/{userId}/{globalThis.encodeURIComponent(email.strip().lower())}";
}
