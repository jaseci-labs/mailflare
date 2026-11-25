glob:priv WEBP: any = record({"httpMetadata": record({"contentType": "image/webp"})});

def avatarPreviewKeyFor(key: str) -> str {
    return f"{key}:preview";
}

def:priv webp_within(file: any, limit: int) -> bool {
    webp = isinstance(file, globalThis.File) and file["type"] == "image/webp";
    return webp and bool(file.size) and file.size <= limit;
}

"""The full avatar (at most 1 MiB) and its preview (32 KiB), both WebP, or null."""
def getOptimizedAvatarFiles(form: any) -> any {
    (full, preview) = (form.get("file"), form.get("preview"));
    ok = webp_within(full, 1024 * 1024) and webp_within(preview, 32 * 1024);
    return {"full": full, "preview": preview} if ok else NULL;
}

async def storeAvatarImages(bucket: any, key: str, full: any, preview: any) {
    await bucket.put(avatarPreviewKeyFor(key), await preview.arrayBuffer(), WEBP);
    await bucket.put(key, await full.arrayBuffer(), WEBP);
}

async def deleteAvatarImages(bucket: any, key: str) {
    await bucket.delete([key, avatarPreviewKeyFor(key)]);
}

async def getAvatarImageResponse(request: any, bucket: any, key: str) -> any {
    url = new(globalThis.URL, request.url);
    preview = url.searchParams.get("variant") == "preview";
    stored = await bucket.get(avatarPreviewKeyFor(key) if preview else key);
    if not stored {
        return new(globalThis.Response, "Not found", record({"status": 404}));
    }
    # Uploads change the URL's version. Unversioned URLs refresh within five minutes
    # without an authenticated DB/storage round trip on every component remount.
    versioned = url.searchParams.has("v");
    caching = "private, max-age=31536000, immutable" if versioned else "private, max-age=300";
    ct = dig(stored, ["httpMetadata", "contentType"], "application/octet-stream");
    csp = "default-src 'none'; img-src 'self'; sandbox";
    hs = {"Content-Type": ct, "X-Content-Type-Options": "nosniff", "Content-Security-Policy": csp};
    # The same URL can resolve to different images after switching accounts.
    hs = {**hs, "Cache-Control": caching, "Vary": "Cookie, Authorization", "ETag": stored.httpEtag};
    headers = new(globalThis.Headers, record(hs));
    if request.headers.get("If-None-Match") == stored.httpEtag {
        return new(globalThis.Response, NULL, record({"status": 304, "headers": headers}));
    }
    return new(globalThis.Response, stored.body, record({"headers": headers}));
}
