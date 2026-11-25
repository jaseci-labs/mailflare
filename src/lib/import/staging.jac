# Messages per staged object, and per queue message that consumes one.
glob IMPORT_BATCH_SIZE = 25;

def importBatchKey(jobId: str, batch: int) -> str {
    return f"import-jobs/{jobId}/{batch}.bin";
}

# `[u32 header length][JSON header][raw message bytes...]`: one bucket write per batch, not per message.
def packImportMessages(items: any) -> any {
    meta = [merged(i, {"size": i["raw"].byteLength}) for i in items];
    fields = "filename size read starred".split();
    head = new(globalThis.TextEncoder).encode(globalThis.JSON.stringify(meta, fields));
    out = new(globalThis.Uint8Array, 4 + head.byteLength + sum([m["size"] for m in meta]));
    new(globalThis.DataView, out.buffer).setUint32(0, head.byteLength);
    out.set(head, 4);
    offset = 4 + head.byteLength;
    for m in meta {
        out.set(new(globalThis.Uint8Array, m["raw"]), offset);
        offset += m["size"];
    }
    return out;
}

def unpackImportMessages(data: any) -> list[any] {
    n = new(globalThis.DataView, data.buffer, data.byteOffset, data.byteLength).getUint32(0);
    header = globalThis.JSON.parse(new(globalThis.TextDecoder).decode(data.subarray(4, 4 + n)));
    (offset, out) = (4 + n, []);
    for h in header {
        m = {"filename": h["filename"], "raw": data.slice(offset, offset + h["size"]).buffer};
        out.append(merged(m, {k: h[k] for k in ["read", "starred"] if owns(h, k)}));
        offset += h["size"];
    }
    return out;
}

# Stages messages in batches and returns how many objects were written.
async def stageImportMessages(env: any, jobId: str, messages: any) -> int {
    batches = 0;
    try {
        for start in range(0, len(messages), IMPORT_BATCH_SIZE) {
            batch = packImportMessages(messages[start:start + IMPORT_BATCH_SIZE]);
            await env.BUCKET.put(importBatchKey(jobId, batches), batch);
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
