def:priv encoded(text: str) -> any {
    return new(globalThis.TextEncoder).encode(text);
}

async def:priv sha256_hex(data: any) -> str {
    digest = await globalThis.crypto.subtle.digest("SHA-256", data);
    return globalThis.Array.prototype.map.call(
        new(globalThis.Uint8Array, digest),
        lambda (b: any) -> any { b.toString(16).padStart(2, "0") },
    ).join("");
}

async def inboundMessageId(rawR2Key: str) -> str {
    return "msg_" + await sha256_hex(encoded(rawR2Key));
}

"""Deterministic storage key for an inbound message, from the mailbox and the raw bytes.

A relay retry replays identical bytes, so it overwrites the same object and the inbound queue
consumer, which dedupes by `(mailboxId, rawR2Key)`, skips it. Sender-controlled headers such as
`Message-ID` are deliberately not part of the key: a third party who knows a message's
`Message-ID` could otherwise overwrite its stored raw MIME or make the real delivery look like a
duplicate.
"""
async def inboundStorageKey(raw: any, mailboxId: any = None) -> str {
    prefix = encoded(either(mailboxId, "") + "\0");
    joined = new(globalThis.Uint8Array, prefix.length + raw.byteLength);
    joined.set(prefix, 0);
    joined.set(new(globalThis.Uint8Array, raw), prefix.length);
    return "inbound/" + await sha256_hex(joined) + ".eml";
}
