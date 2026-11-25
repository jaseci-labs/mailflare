# JMAP Mailbox ids encode Mailflare's model: a top-level Mailbox per mailbox (all its mail), system
# children keyed by status, one child per user folder. Ids are stable strings clients can cache.
# Every JMAP request encodes and decodes ids per item, so these read strings with JavaScript's own
# methods through `globalThis` (a direct call), build plain objects, and make no tuples.
glob SYSTEM_ROLES: list[str] = ["inbox", "sent", "drafts", "archive", "junk", "trash"];
glob:priv STATUS: any = dict(zip(SYSTEM_ROLES, "received sent draft archived spam trash".split())),
          ROLE: any = {**{v: k for (k, v) in STATUS.items()}, "queued": "sent", "failed": "sent"};

# `o.name(...args)` as JavaScript calls it, for a value that is not a string.
def:priv js_call(o: any, name: str, args: list[any]) -> any {
    return globalThis.Reflect.apply(globalThis.Reflect.get(o, name), o, args);
}

def:priv index_of(s: any, sep: str, start: int = 0) -> int {
    if isinstance(s, str) {
        return globalThis.String.prototype.indexOf.call(s, sep, start);
    }
    return js_call(s, "indexOf", [sep, start]);
}

def:priv slice(s: any, start: int, end: any = None) -> any {
    return globalThis.String.prototype.slice.call(s, start, end);
}

# `${a}${b}...` (template literals convert as `String.prototype.concat` does).
def:priv join(a: any, b: any, c: any, d: any = "", e: any = "") -> str {
    return globalThis.String.prototype.concat.call("", a, b, c, d, e);
}

def encodeMailboxRef(ref: any) -> any {
    kind = globalThis.Reflect.get(ref, "kind");
    if kind == "account" {
        return globalThis.Reflect.get(ref, "mailboxId");
    }
    if kind == "role" {
        return join(globalThis.Reflect.get(ref, "mailboxId"), "~", globalThis.Reflect.get(ref, "role"));
    }
    return join(globalThis.Reflect.get(ref, "mailboxId"), "~", "f", "~", globalThis.Reflect.get(ref, "folderId"));
}

def:priv account_ref(box: any) -> any {
    out: any = globalThis.Object();
    out.kind = "account";
    out.mailboxId = box;
    return out;
}

def:priv role_ref(box: any, role: any) -> any {
    out: any = globalThis.Object();
    out.kind = "role";
    out.mailboxId = box;
    out.role = role;
    return out;
}

def:priv folder_ref(box: any, folder: any) -> any {
    out: any = globalThis.Object();
    out.kind = "folder";
    out.mailboxId = box;
    out.folderId = folder;
    return out;
}

def:priv blob_ref(kind: any, id: any) -> any {
    out: any = globalThis.Object();
    out.kind = kind;
    out.id = id;
    return out;
}

def:priv identity_ref(mailboxId: any, address: any) -> any {
    out: any = globalThis.Object();
    out.mailboxId = mailboxId;
    out.address = address;
    return out;
}
# `id.split("~")` of what is not a string, read as the original reads its parts.
def:priv decode_parts(parts: any) -> any {
    n = globalThis.Reflect.get(parts, "length");
    p0 = globalThis.Reflect.get(parts, 0);
    p1 = globalThis.Reflect.get(parts, 1);
    p2 = globalThis.Reflect.get(parts, 2);
    if n == 1 and p0 {
        return account_ref(p0);
    }
    if n == 2 and globalThis.Array.prototype.includes.call(SYSTEM_ROLES, p1) {
        return role_ref(p0, p1);
    }
    if n == 3 and p1 == "f" and p2 {
        return folder_ref(p0, p2);
    }
    return NULL;
}

def decodeMailboxRef(id: any) -> any {
    if not isinstance(id, str) {
        return decode_parts(js_call(id, "split", ["~"]));
    }
    i: int = globalThis.String.prototype.indexOf.call(id, "~");
    if i < 0 {
        return account_ref(id) if id else NULL;
    }
    j: int = globalThis.String.prototype.indexOf.call(id, "~", i + 1);
    if j < 0 {
        role = slice(id, i + 1);
        return role_ref(slice(id, 0, i), role) if role in SYSTEM_ROLES else NULL;
    }
    k: int = globalThis.String.prototype.indexOf.call(id, "~", j + 1);
    if k < 0 and j == i + 2 and slice(id, i + 1, j) == "f" {
        folder = slice(id, j + 1);
        return folder_ref(slice(id, 0, i), folder) if folder else NULL;
    }
    return NULL;
}

# Blob ids name either a stored attachment, a message's raw MIME, or a client upload.
def attachmentBlobId(attachmentId: str) -> str {
    return join("att", "~", attachmentId);
}

def messageBlobId(messageId: str) -> str {
    return join("msg", "~", messageId);
}

def uploadBlobId(uploadId: str) -> str {
    return join("up", "~", uploadId);
}

def decodeBlobId(blobId: any) -> any {
    index = index_of(blobId, "~");
    if index < 0 {
        return NULL;
    }
    kind = js_call(blobId, "slice", [0, index]) if not isinstance(blobId, str) else slice(blobId, 0, index);
    id = js_call(blobId, "slice", [index + 1]) if not isinstance(blobId, str) else slice(blobId, index + 1);
    if not id or (kind != "att" and kind != "msg" and kind != "up") {
        return NULL;
    }
    return blob_ref(kind, id);
}

def identityId(mailboxId: any, address: any) -> str {
    if isinstance(address, str) {
        lower = globalThis.String.prototype.toLowerCase.call(address);
    } else {
        lower = js_call(address, "toLowerCase", []);
    }
    return join(mailboxId, "~", lower);
}

def decodeIdentityId(id: any) -> any {
    index = index_of(id, "~");
    if index < 0 {
        return NULL;
    }
    if not isinstance(id, str) {
        return identity_ref(js_call(id, "slice", [0, index]), js_call(id, "slice", [index + 1]));
    }
    return identity_ref(slice(id, 0, index), slice(id, index + 1));
}

# Status/folder predicate for each system role, as a plain description the query layer turns into SQL.
def roleToStatus(role: any) -> any {
    return STATUS.get(role) if isinstance(role, str) else None;
}

def statusToRole(status: any) -> any {
    return ROLE.get(status, NULL) if isinstance(status, str) else NULL;
}
