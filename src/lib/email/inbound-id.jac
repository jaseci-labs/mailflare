# Hex SHA-256 of `parts` one after another, strings as UTF-8.
async def:priv sha256_hex(*parts: any) -> str {
    data = await new(globalThis.Blob, parts).arrayBuffer();
    digest = new(globalThis.Uint8Array, await globalThis.crypto.subtle.digest("SHA-256", data));
    return "".join([globalThis.String(b.toString(16)).padStart(2, "0") for b in digest]);
}

async def inboundMessageId(rawR2Key: str) -> str {
    return "msg_" + await sha256_hex(rawR2Key);
}

# Deterministic storage key from the mailbox and the raw bytes: a relay retry replays identical
# bytes, overwriting the same object, and the inbound consumer (deduping by `(mailboxId, rawR2Key)`)
# skips it. Sender-controlled headers such as `Message-ID` are deliberately left out: a third party
# who knows one could otherwise overwrite stored raw MIME or make the real delivery a duplicate.
async def inboundStorageKey(raw: any, mailboxId: any = None) -> str {
    return "inbound/" + await sha256_hex(either(mailboxId, ""), "\0", raw) + ".eml";
}
