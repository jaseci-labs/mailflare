import from "drizzle-orm" { eq, isNull, and as allOf }

glob UPLOAD_PREFIX = "jmap-uploads";
# Ids `storeUpload` hands out (`newId("upl")`). Anything else, such as `../` segments, could reach keys outside the user's prefix.
glob:priv UPLOAD_ID: any = rx(r"^upl_[\w-]+$");

"""Uploads are namespaced by user, so only the account that stored one can read it."""
def:priv upload_key(ctx: any, uploadId: str) -> str {
    return f"{UPLOAD_PREFIX}/{ctx.auth.userId}/{uploadId}";
}

"""`o.a?.b ?? fallback`."""
def:priv dig(o: any, a: str, b: str, fallback: any) -> any {
    inner = at(o, a);
    return fallback if nil(inner) else at(inner, b, fallback);
}

"""A row's blob is off limits unless its mailbox is accessible and it is not someone else's draft."""
def:priv unreadable(ctx: any, row: any, accessible: any) -> bool {
    return not row
        or not row.mailboxId
        or not accessible.has(row.mailboxId)
        or isOthersDraft(row, ctx.auth.userId);
}

"""Client uploads live in R2 under the user until a draft claims them."""
async def storeUpload(ctx: any, body: any, kind: any, name: any) -> any {
    if body.byteLength > LIMITS.maxSizeUpload {
        return NULL;
    }
    id = newId("upl");
    await ctx.env.BUCKET.put(
        upload_key(ctx, id),
        body,
        record({
            "httpMetadata": record({"contentType": kind}),
            "customMetadata": merged({"userId": ctx.auth.userId}, {"name": name} if name else {}),
        }),
    );
    return record({
        "accountId": ctx.accountId,
        "blobId": uploadBlobId(id),
        "type": kind,
        "size": body.byteLength,
    });
}

async def readUpload(ctx: any, uploadId: str) -> any {
    if not UPLOAD_ID.test(uploadId) {
        return NULL;
    }
    object = await ctx.env.BUCKET.get(upload_key(ctx, uploadId));
    if not object {
        return NULL;
    }
    return record({
        "content": await object.arrayBuffer(),
        "type": dig(object, "httpMetadata", "contentType", "application/octet-stream"),
        "name": dig(object, "customMetadata", "name", NULL),
    });
}

"""Drop an upload once a message owns its bytes."""
async def deleteUpload(ctx: any, uploadId: str) {
    if UPLOAD_ID.test(uploadId) {
        await ctx.env.BUCKET.delete(upload_key(ctx, uploadId));
    }
}

"""Keep the exact MIME an imported message arrived as.

This mirrors the `inbound/` copy the mail pipeline stores, so `readBlob` serves
the client its own bytes back instead of the rebuilt minimal message.
"""
async def storeRawDraftMime(ctx: any, messageId: str, raw: any) -> str {
    key = f"drafts/{messageId}.eml";
    await ctx.env.BUCKET.put(
        key,
        raw,
        record({
            "httpMetadata": record({"contentType": "message/rfc822"}),
            "customMetadata": record({"userId": ctx.auth.userId, "messageId": messageId}),
        }),
    );
    return key;
}

def:priv blob(body: any, kind: any, name: any, size: any) -> any {
    return record({"body": body, "type": kind, "name": name, "size": size});
}

"""Resolve a blob id to bytes the account may read.

That is an attachment on one of its messages, the raw MIME of one of its
messages, or its own upload.
"""
async def readBlob(ctx: any, blobId: str) -> any {
    decoded = decodeBlobId(blobId);
    if not decoded {
        return NULL;
    }
    accessible = await listAccessibleMailboxIdSet(ctx);
    if decoded["kind"] == "up" {
        upload = await readUpload(ctx, decoded["id"]);
        return blob(upload.content, upload.type, upload.name, upload.content.byteLength)
            if upload
            else NULL;
    }
    if decoded["kind"] == "att" {
        found = await ctx.db.select(
            record({
                "r2Key": messageAttachments.r2Key,
                "filename": messageAttachments.filename,
                "type": messageAttachments.contentType,
                "size": messageAttachments.size,
                "mailboxId": messages.mailboxId,
                "status": messages.status,
                "privateDraft": messages.privateDraft,
                "userId": messages.userId,
            }),
        ).from(messageAttachments).innerJoin(
            messages, eq(messageAttachments.messageId, messages.id)
        ).where(
            allOf(eq(messageAttachments.id, decoded["id"]), isNull(messageAttachments.trashedAt))
        ).limit(1);
        attachment = found[0] if len(found) else None;
        if unreadable(ctx, attachment, accessible) {
            return NULL;
        }
        stored = await ctx.env.BUCKET.get(attachment.r2Key);
        return blob(stored.body, attachment.type, attachment.filename, attachment.size)
            if stored
            else NULL;
    }
    rows = await ctx.db.select().from(messages).where(allOf(eq(messages.id, decoded["id"]))).limit(
        1
    );
    row = rows[0] if len(rows) else None;
    if unreadable(ctx, row, accessible) {
        return NULL;
    }
    if row.rawR2Key {
        raw = await ctx.env.BUCKET.get(row.rawR2Key);
        if raw {
            return blob(raw.body, "message/rfc822", f"{row.id}.eml", raw.size);
        }
    }
    # Outbound and imported mail keeps no raw copy; rebuild a minimal RFC 5322 message.
    lines = [
        f"From: {row.fromAddr}",
        f"To: {row.toAddr}",
        *([f"Cc: {row.ccAddr}"] if row.ccAddr else []),
        f"Subject: {either(row.subject, '')}",
        f"Date: {row.createdAt.toUTCString()}",
        *([f"Message-ID: {row.providerMessageId}"] if row.providerMessageId else []),
        *([f"In-Reply-To: <{row.inReplyTo}>"] if row.inReplyTo else []),
        "MIME-Version: 1.0",
        f"Content-Type: {'text/html' if row.htmlBody else 'text/plain'}; charset=utf-8",
        "",
        either(row.htmlBody, either(row.textBody, "")),
    ];
    data = new(globalThis.TextEncoder).encode("\r\n".join(lines));
    return blob(data.buffer, "message/rfc822", f"{row.id}.eml", data.byteLength);
}
