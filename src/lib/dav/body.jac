# Largest body for PROPFIND, PROPPATCH and REPORT.
glob MAX_XML_BODY: int = 256 * 1024;

"""
Read a request body as text, stopping at `limit` bytes. The Content-Length header is only a hint,
so the stream itself is counted. Returns null when the body is too large.
"""
async def readBodyText(request: any, limit: int) -> any {
    declared = globalThis.Number(either(request.headers.get("content-length"), 0));
    if globalThis.Number.isFinite(declared) and declared > limit {
        return NULL;
    }
    if not request.body {
        return "";
    }
    reader = request.body.getReader();
    chunks: list[any] = [];
    size = 0;
    while True {
        step = await reader.read();
        if step.done {
            break;
        }
        size += step.value.byteLength;
        if size > limit {
            await reader.cancel().catch(lambda (e: any) -> any { None });
            return NULL;
        }
        chunks.append(step.value);
    }
    data = new(globalThis.Uint8Array, size);
    offset = 0;
    for chunk in chunks {
        data.set(chunk, offset);
        offset += chunk.byteLength;
    }
    return new(globalThis.TextDecoder).decode(data);
}
