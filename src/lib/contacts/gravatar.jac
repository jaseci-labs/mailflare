glob:priv MAX_SIZE: int = 2 * 1024 * 1024,
          TYPES: list[str] = "image/gif image/jpeg image/png image/webp".split();

# The media type a response declares, without parameters; undefined when it declares none.
def:priv kind_of(res: any) -> any {
    h = res.headers.get("Content-Type");
    return None if nil(h) else globalThis.String(h.split(";")[0]).trim().toLowerCase();
}

def:priv stored_as(kind: str) -> any {
    return record({"httpMetadata": record({"contentType": kind})});
}

"""Copies the address's Gravatar (and a small preview) into the bucket; null when there is none or it is not an allowed image."""
async def importGravatarAvatar(env: any, userId: str, email: any) -> any {
    try {
        addr = email.trim().toLowerCase();
        digest = await globalThis.crypto.subtle.digest(
            "SHA-256", new(globalThis.TextEncoder).encode(addr)
        );
        hex = "".join([
            b.toString(16).padStart(2, "0")
            for b in globalThis.Array.from(new(globalThis.Uint8Array, digest))
        ]);
        url = f"https://gravatar.com/avatar/{hex}?d=404&r=g&s=";
        res = await globalThis.fetch(url + "256");
        if not res.ok {
            return NULL;
        }
        (kind, size) = (
            kind_of(res),
            globalThis.Number(either(res.headers.get("Content-Length"), 0)),
        );
        if not kind or kind not in TYPES or size > MAX_SIZE {
            return NULL;
        }
        image = await res.arrayBuffer();
        if image.byteLength > MAX_SIZE {
            return NULL;
        }
        key = contactAvatarKeyFor(userId, addr);
        await env.BUCKET.put(key, image, stored_as(kind));
        try {
            small = await globalThis.fetch(url + "16");
            (pk, preview) = (kind_of(small), await small.arrayBuffer())
                if small.ok
                else (None, None);
            if pk and pk in TYPES and preview.byteLength <= 32 * 1024 {
                await env.BUCKET.put(avatarPreviewKeyFor(key), preview, stored_as(pk));
            }
        } except Exception {
            # The full avatar is still available if the preview request fails.
        }
        return key;
    } except Exception {
        return NULL;
    }
}
