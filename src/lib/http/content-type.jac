glob:priv TOKEN: str = "[a-z0-9!#$&^_.+-]+";

# Types a browser shows without running script, so they may render inline on our origin.
glob:priv INLINE: set[str] = set("""application/pdf application/json text/plain text/csv image/png
    image/jpeg image/gif image/webp image/avif image/bmp""".split());

"""The lowercase `type/subtype` of a Content-Type value, or null unless one well-formed type."""
def getMimeEssence(contentType: any = None) -> any {
    # Browsers read a comma-joined value as several types and use the last: never guess which wins.
    if not contentType or "," in contentType {
        return NULL;
    }
    essence: any = contentType.split(";")[0];
    essence = essence.trim().toLowerCase();
    return essence if rx(f"^{TOKEN}/{TOKEN}$").test(essence) else NULL;
}

"""
The Content-Type to serve a sender- or uploader-supplied file with when it may render inline, or
null when it must download. Only the parsed essence is checked and sent back: echoing the raw value
would let `image/svg+xml;charset=utf-8` or `image/png; x=1, text/html` pass a check of the type.
"""
def getInlineContentType(contentType: any = None) -> any {
    e = getMimeEssence(contentType);
    media = not nil(e) and (e in INLINE or e.startswith("audio/") or e.startswith("video/"));
    if not media or not e.startswith("text/") {
        return e if media else NULL;
    }
    charset = rx(r';\s*charset\s*=\s*"?([a-z0-9_.:-]+)"?\s*(?:;|$)', "i").exec(contentType);
    return f"{e}; charset={charset[1]}" if charset else e;
}
