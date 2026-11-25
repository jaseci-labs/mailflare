glob:priv MAX_GRAVATAR_SIZE: int = 2 * 1024 * 1024,
          ALLOWED_GRAVATAR_TYPES: list[str] = [
              "image/gif",
              "image/jpeg",
              "image/png",
              "image/webp",
          ];

"""The media type a response declares, without parameters; None when it declares none."""
def:priv content_type(response: any) -> any {
    header = response.headers.get("Content-Type");
    if nil(header) {
        return None;
    }
    first: any = header.split(";")[0];
    return first.trim().toLowerCase();
}

def:priv stored_as(kind: str) -> any {
    return record({"httpMetadata": {"contentType": kind}});
}

"""Copies the address's Gravatar (and a small preview) into the bucket; null when there is none or it is not an allowed image."""
async def importGravatarAvatar(env: any, userId: str, email: any) -> any {
    try {
        normalizedEmail = email.trim().toLowerCase();
        digest = await globalThis.crypto.subtle.digest(
            "SHA-256", new(globalThis.TextEncoder).encode(normalizedEmail)
        );
        hash = "".join([
            b.toString(16).padStart(2, "0")
            for b in globalThis.Array.from(new(globalThis.Uint8Array, digest))
        ]);
        response = await globalThis.fetch(f"https://gravatar.com/avatar/{hash}?d=404&r=g&s=256");
        if not response.ok {
            return NULL;
        }
        contentType = content_type(response);
        declaredSize = globalThis.Number(either(response.headers.get("Content-Length"), 0));
        if not contentType or contentType not in ALLOWED_GRAVATAR_TYPES {
            return NULL;
        }
        if declaredSize > MAX_GRAVATAR_SIZE {
            return NULL;
        }
        image = await response.arrayBuffer();
        if image.byteLength > MAX_GRAVATAR_SIZE {
            return NULL;
        }
        key = contactAvatarKeyFor(userId, normalizedEmail);
        await env.BUCKET.put(key, image, stored_as(contentType));
        try {
            small = await globalThis.fetch(f"https://gravatar.com/avatar/{hash}?d=404&r=g&s=16");
            if small.ok {
                previewType = content_type(small);
                preview = await small.arrayBuffer();
                if previewType
                    and previewType in ALLOWED_GRAVATAR_TYPES
                    and preview.byteLength <= 32 * 1024
                {
                    await env.BUCKET.put(avatarPreviewKeyFor(key), preview, stored_as(previewType));
                }
            }
        } except Exception {
            # The full avatar is still available if the preview request fails.
        }
        return key;
    } except Exception {
        return NULL;
    }
}
