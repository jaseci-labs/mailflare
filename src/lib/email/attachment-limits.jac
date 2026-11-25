glob DEFAULT_OUTBOUND_ATTACHMENT_MAX_MB: int = 25,
     # Cloudflare Email Sending sends files over this size as download links.
     CLOUD_ATTACHMENT_THRESHOLD_BYTES: int = 3_000_000;

# Workers hold each file in a 128 MB isolate, so 25 MB is their ceiling; Node has far more memory.
glob:priv WORKERS_ATTACHMENT_CEILING_MB: int = 25,
          NODE_ATTACHMENT_CEILING_MB: int = 50,
          LEGACY_REQUEST_BODY_BYTES: int = 30 * 1024 * 1024,
          # Cloudflare's 5 MiB message limit, less a safety margin for the MIME around the files.
          CLOUDFLARE_ROOM_BYTES: int = 5 * 1024 * 1024 - 256 * 1024,
          # Resend/SES attach up to 20 MB (base64 grows a file by a third, servers refuse ~25 MB mail).
          OTHER_PROVIDER_ATTACHMENT_BYTES: int = 20_000_000;

# The most an administrator can allow on this runtime.
def outboundAttachmentCeilingMb(nodeRuntime: bool) -> int {
    return NODE_ATTACHMENT_CEILING_MB if nodeRuntime else WORKERS_ATTACHMENT_CEILING_MB;
}

# A stored or submitted limit forced into 1 to the runtime's ceiling; unusable values give the default.
def clampOutboundAttachmentMb(value: any, nodeRuntime: bool) -> int {
    if not globalThis.Number.isFinite(value) {
        return DEFAULT_OUTBOUND_ATTACHMENT_MAX_MB;
    }
    whole = globalThis.Math.max(globalThis.Math.trunc(value), 1);
    return globalThis.Math.min(whole, outboundAttachmentCeilingMb(nodeRuntime));
}

# Error text when any file, or all of them together, break the administrator's limit; else null.
def outgoingSizeError(sizes: any, maxMb: any) -> any {
    limit = maxMb * 1_000_000;
    if any(size > limit for size in sizes) or sum(sizes) > limit {
        return f"Attachments exceed the administrator's {globalThis.String(maxMb)} MB outgoing limit";
    }
    return NULL;
}

# Largest send/upload body: the legacy 30 MiB cap until the limit is raised, then room for base64.
def requestBodyLimit(maxMb: any) -> int {
    if maxMb <= DEFAULT_OUTBOUND_ATTACHMENT_MAX_MB {
        return LEGACY_REQUEST_BODY_BYTES;
    }
    return globalThis.Math.ceil(maxMb * 1_000_000 * 4 / 3) + 5 * 1024 * 1024;
}

# For each file, true when it must go as a Shared Files link instead of an attachment. `baseBytes`
# is the size of the message without its files (Cloudflare counts the whole encoded message).
def planAttachmentDelivery(provider: str, sizes: any, baseBytes: any) -> list[bool] {
    cloudflare = provider == "cloudflare";
    used = baseBytes if cloudflare else 0;
    single = CLOUD_ATTACHMENT_THRESHOLD_BYTES if cloudflare else OTHER_PROVIDER_ATTACHMENT_BYTES;
    room = CLOUDFLARE_ROOM_BYTES if cloudflare else OTHER_PROVIDER_ATTACHMENT_BYTES;
    linked: list[bool] = [];
    for size in sizes {
        cost = globalThis.Math.ceil(size / 3) * 4 + 2048 if cloudflare else size;
        direct = size <= single and used + cost <= room;
        used += cost if direct else 0;
        linked.append(not direct);
    }
    return linked;
}
