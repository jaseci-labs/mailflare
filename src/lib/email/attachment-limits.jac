glob DEFAULT_OUTBOUND_ATTACHMENT_MAX_MB: int = 25;

# Cloudflare Email Sending sends files over this size as download links.
glob CLOUD_ATTACHMENT_THRESHOLD_BYTES: int = 3_000_000;

# Workers hold each file in a 128 MB isolate while it is read and sent, so 25 MB stays the
# ceiling there; Node/Docker have far more memory.
glob:priv WORKERS_ATTACHMENT_CEILING_MB: int = 25,
          NODE_ATTACHMENT_CEILING_MB: int = 50,
          LEGACY_REQUEST_BODY_BYTES: int = 30 * 1024 * 1024,
          CLOUDFLARE_MESSAGE_LIMIT_BYTES: int = 5 * 1024 * 1024,
          MIME_SAFETY_MARGIN_BYTES: int = 256 * 1024;

# Resend and SES attach directly up to 20 MB: encoding grows a file by a third, and many
# receiving servers refuse messages over about 25 MB. Larger files go as download links.
glob:priv OTHER_PROVIDER_ATTACHMENT_BYTES: int = 20_000_000;

"""The most an administrator can allow on this runtime."""
def outboundAttachmentCeilingMb(nodeRuntime: bool) -> int {
    return NODE_ATTACHMENT_CEILING_MB if nodeRuntime else WORKERS_ATTACHMENT_CEILING_MB;
}

"""A stored or submitted limit forced into 1 to the runtime's ceiling; unusable values give the default."""
def clampOutboundAttachmentMb(value: any, nodeRuntime: bool) -> int {
    if not globalThis.Number.isFinite(value) {
        return DEFAULT_OUTBOUND_ATTACHMENT_MAX_MB;
    }
    return globalThis.Math.min(
        globalThis.Math.max(globalThis.Math.trunc(value), 1),
        outboundAttachmentCeilingMb(nodeRuntime),
    );
}

"""An error message when the files break the administrator's limit (each file and all files together), else null."""
def outgoingSizeError(sizes: any, maxMb: any) -> any {
    max_bytes = maxMb * 1_000_000;
    total = 0;
    over = False;
    for size in sizes {
        total += size;
        over = over or size > max_bytes;
    }
    if over or total > max_bytes {
        return f"Attachments exceed the administrator's {globalThis.String(maxMb)} MB outgoing limit";
    }
    return NULL;
}

"""Largest request body a send or upload may carry: the old 30 MiB cap until the limit is raised, then room for a base64 body."""
def requestBodyLimit(maxMb: any) -> int {
    if maxMb <= DEFAULT_OUTBOUND_ATTACHMENT_MAX_MB {
        return LEGACY_REQUEST_BODY_BYTES;
    }
    return globalThis.Math.ceil(maxMb * 1_000_000 * 4 / 3) + 5 * 1024 * 1024;
}

"""For each file, true when it must go as a Shared Files link instead of an attachment.

`baseBytes` is the size of the message without its files (Cloudflare counts the whole encoded message).
"""
def planAttachmentDelivery(provider: str, sizes: any, baseBytes: any) -> list[bool] {
    cloudflare = provider == "cloudflare";
    used = baseBytes if cloudflare else 0;
    (single, room) = (
        CLOUD_ATTACHMENT_THRESHOLD_BYTES,
        CLOUDFLARE_MESSAGE_LIMIT_BYTES - MIME_SAFETY_MARGIN_BYTES,
    )
        if cloudflare
        else (OTHER_PROVIDER_ATTACHMENT_BYTES, OTHER_PROVIDER_ATTACHMENT_BYTES);
    linked: list[bool] = [];
    for size in sizes {
        cost = globalThis.Math.ceil(size / 3) * 4 + 2048 if cloudflare else size;
        direct = size <= single and used + cost <= room;
        if direct {
            used += cost;
        }
        linked.append(not direct);
    }
    return linked;
}
