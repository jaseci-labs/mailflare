import from "drizzle-orm" { eq, inArray }

glob:priv MAILBOX_FIELDS: list[str] = [
    "id",
    "userId",
    "localPart",
    "hostname",
    "displayName",
    "permission",
    "type",
    "isPrimary",
];

async def:priv load_jmap_mailboxes(ctx: any) -> list[any] {
    rows = await listAccessibleMailboxes(ctx.db, ctx.auth.user);
    allowed = at(ctx.auth, "mailboxIds");
    return [
        record({field: row[field] for field in MAILBOX_FIELDS})
        for row in rows
        if nil(allowed) or row.id in allowed
    ];
}

"""Every Mailflare mailbox the key's user can read, in a JMAP-shaped record."""
def listJmapMailboxes(ctx: any) -> any {
    if getattr(ctx, "memo", None) is NULL {
        return load_jmap_mailboxes(ctx);
    }
    if getattr(ctx, "memo", None) is None {
        ctx.memo = globalThis.Object();
    }
    memo = ctx.memo;
    if not getattr(memo, "mailboxes", None) {
        # A coroutine runs once, only when awaited; a promise starts now and can be shared.
        pending: any = globalThis.Promise.resolve(load_jmap_mailboxes(ctx));
        memo.mailboxes = pending;
        # A failed lookup is retried by the next call instead of failing it too.
        def forget(error: any) {
            if memo.mailboxes is pending {
                memo.mailboxes = None;
            }
        }
        pending.catch(forget);
    }
    return memo.mailboxes;
}

async def listAccessibleMailboxIdSet(ctx: any) -> any {
    return new(globalThis.Set, [row.id for row in await listJmapMailboxes(ctx)]);
}

"""What `listFoldersByMailbox` gives: a JavaScript Map would reach TypeScript as a plain object, so this stands in with the Map's `get`."""
obj:priv FolderIndex {
    has lists: dict[str, list[any]];

    def get(mailboxId: str) -> any {
        return self.lists.get(mailboxId);
    }
}

"""User folders for a set of mailboxes, keyed by mailbox id."""
async def listFoldersByMailbox(ctx: any, mailboxIds: any) -> FolderIndex {
    result = FolderIndex(lists={});
    if len(mailboxIds) == 0 {
        return result;
    }
    rows = await ctx.db.select(
        record({"id": folders.id, "mailboxId": folders.mailboxId, "name": folders.name})
    ).from(folders).where(inArray(folders.mailboxId, mailboxIds));
    for row in rows {
        result.lists.setdefault(row.mailboxId, []).append(record({"id": row.id, "name": row.name}));
    }
    return result;
}

"""Addresses each mailbox may send from, for Identity objects."""
async def listSendableAddresses(ctx: any, mailbox: any) -> any {
    rows = await ctx.db.select().from(mailboxes).where(eq(mailboxes.id, mailbox.id)).limit(1);
    if not len(rows) {
        return [];
    }
    return getMailboxDomainAddresses(ctx.db, rows[0]);
}
