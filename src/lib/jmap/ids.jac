"""JMAP Mailbox ids encode Mailflare's model.

A top-level Mailbox per Mailflare mailbox (all its mail), system children keyed
by status, and one child per user folder. Ids are stable strings so clients can
cache them.
"""

glob:priv SEP = "~";
glob SYSTEM_ROLES: list[str] = ["inbox", "sent", "drafts", "archive", "junk", "trash"];

glob:priv ROLE_STATUS: dict[str, str] = {
              "inbox": "received",
              "sent": "sent",
              "drafts": "draft",
              "archive": "archived",
              "junk": "spam",
              "trash": "trash",
          },
          STATUS_ROLE: dict[str, any] = {
              "received": "inbox",
              "sent": "sent",
              "queued": "sent",
              "failed": "sent",
              "draft": "drafts",
              "archived": "archive",
              "spam": "junk",
              "trash": "trash",
          };

def encodeMailboxRef(ref: any) -> str {
    if ref["kind"] == "account" {
        return ref["mailboxId"];
    }
    if ref["kind"] == "role" {
        return f"{ref['mailboxId']}{SEP}{ref['role']}";
    }
    return f"{ref['mailboxId']}{SEP}f{SEP}{ref['folderId']}";
}

def decodeMailboxRef(id: str) -> any {
    parts = id.split(SEP);
    if len(parts) == 1 and parts[0] {
        return {"kind": "account", "mailboxId": parts[0]};
    }
    if len(parts) == 2 and parts[1] in SYSTEM_ROLES {
        return {"kind": "role", "mailboxId": parts[0], "role": parts[1]};
    }
    if len(parts) == 3 and parts[1] == "f" and parts[2] {
        return {"kind": "folder", "mailboxId": parts[0], "folderId": parts[2]};
    }
    return NULL;
}

# Blob ids name either a stored attachment, a message's raw MIME, or a client upload.
def attachmentBlobId(attachmentId: str) -> str {
    return f"att{SEP}{attachmentId}";
}

def messageBlobId(messageId: str) -> str {
    return f"msg{SEP}{messageId}";
}

def uploadBlobId(uploadId: str) -> str {
    return f"up{SEP}{uploadId}";
}

def decodeBlobId(blobId: str) -> any {
    (kind, sep, id) = blobId.partition(SEP);
    if not sep or not id or kind not in ["att", "msg", "up"] {
        return NULL;
    }
    return {"kind": kind, "id": id};
}

def identityId(mailboxId: str, address: str) -> str {
    return f"{mailboxId}{SEP}{address.lower()}";
}

def decodeIdentityId(id: str) -> any {
    (mailboxId, sep, address) = id.partition(SEP);
    return {"mailboxId": mailboxId, "address": address} if sep else NULL;
}

"""Status/folder predicate for each system role, as a plain description the query layer turns into SQL."""
def roleToStatus(role: str) -> any {
    return ROLE_STATUS.get(role);
}

def statusToRole(status: str) -> any {
    return STATUS_ROLE.get(status, NULL);
}
