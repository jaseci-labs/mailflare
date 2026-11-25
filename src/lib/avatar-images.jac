glob:priv MAX_STORED_AVATAR_SIZE: int = 1024 * 1024,
          MAX_PREVIEW_AVATAR_SIZE: int = 32 * 1024,
          WEBP: any = record({"httpMetadata": record({"contentType": "image/webp"})});

def avatarPreviewKeyFor(key: str) -> str {
    return f"{key}:preview";
}

def:priv webp_within(file: any, limit: int) -> bool {
    return isinstance(file, globalThis.File)
        and file["type"] == "image/webp"
        and bool(file.size)
        and file.size <= limit;
}

def getOptimizedAvatarFiles(form: any) -> any {
    (full, preview) = (form.get("file"), form.get("preview"));
    if not webp_within(full, MAX_STORED_AVATAR_SIZE)
        or not webp_within(preview, MAX_PREVIEW_AVATAR_SIZE)
    {
        return NULL;
    }
    return {"full": full, "preview": preview};
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
    caching = "private, max-age=31536000, immutable"
        if url.searchParams.has("v")
        else "private, max-age=300";
    headers = new(
        globalThis.Headers,
        record({
            "Content-Type": at(
                at(stored, "httpMetadata", {}), "contentType", "application/octet-stream"
            ),
            "X-Content-Type-Options": "nosniff",
            "Content-Security-Policy": "default-src 'none'; img-src 'self'; sandbox",
            "Cache-Control": caching,
            # The same URL can resolve to different images after switching accounts.
            "Vary": "Cookie, Authorization",
            "ETag": stored.httpEtag,
        }),
    );
    if request.headers.get("If-None-Match") == stored.httpEtag {
        return new(globalThis.Response, NULL, record({"status": 304, "headers": headers}));
    }
    return new(globalThis.Response, stored.body, record({"headers": headers}));
}
