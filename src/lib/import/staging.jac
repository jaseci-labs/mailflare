# Messages per staged object, and per queue message that consumes one.
glob IMPORT_BATCH_SIZE = 25;

def importBatchKey(jobId: str, batch: int) -> str {
    return f"import-jobs/{jobId}/{batch}.bin";
}

"""A staged batch is `[u32 header length][JSON header][raw message bytes...]`.

A whole upload then costs one bucket write per batch instead of one per message.
"""
def packImportMessages(items: any) -> any {
    header = new(globalThis.TextEncoder).encode(
        globalThis.JSON.stringify([
            record({
                "filename": item["filename"],
                "size": item["raw"].byteLength,
                "read": item["read"] if owns(item, "read") else None,
                "starred": item["starred"] if owns(item, "starred") else None,
            })
            for item in items
        ]),
    );
    bodySize = sum([item["raw"].byteLength for item in items]);
    out = new(globalThis.Uint8Array, 4 + header.byteLength + bodySize);
    new(globalThis.DataView, out.buffer).setUint32(0, header.byteLength);
    out.set(header, 4);
    offset = 4 + header.byteLength;
    for item in items {
        out.set(new(globalThis.Uint8Array, item["raw"]), offset);
        offset += item["raw"].byteLength;
    }
    return out;
}

def unpackImportMessages(data: any) -> list[any] {
    headerLength = new(
        globalThis.DataView, data.buffer, data.byteOffset, data.byteLength
    ).getUint32(0);
    header = globalThis.JSON.parse(
        new(globalThis.TextDecoder).decode(data.subarray(4, 4 + headerLength))
    );
    offset = 4 + headerLength;
    messages: list[any] = [];
    for item in header {
        message: dict[str, any] = {
            "filename": getattr(item, "filename", None),
            "raw": data.slice(offset, offset + item.size).buffer,
        };
        for flag in ["read", "starred"] {
            if getattr(item, flag, None) is not None {
                message[flag] = getattr(item, flag);
            }
        }
        offset += item.size;
        messages.append(message);
    }
    return messages;
}

"""Stages messages in batches and returns how many objects were written."""
async def stageImportMessages(env: any, jobId: str, messages: any) -> int {
    batches = 0;
    try {
        for start in range(0, len(messages), IMPORT_BATCH_SIZE) {
            await env.BUCKET.put(
                importBatchKey(jobId, batches),
                packImportMessages(messages[start:start + IMPORT_BATCH_SIZE]),
            );
            batches += 1;
        }
    } except Exception {
        await deleteStagedImport(env, jobId, batches);
        raise;
    }
    return batches;
}

async def deleteStagedImport(env: any, jobId: str, batches: int) {
    for batch in range(batches) {
        try {
            await env.BUCKET.delete(importBatchKey(jobId, batch));
        } except Exception {}
    }
}
