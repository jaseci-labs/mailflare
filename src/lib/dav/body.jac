# Largest body for PROPFIND, PROPPATCH and REPORT.
glob MAX_XML_BODY: int = 256 * 1024;

# A request body as text, stopping at `limit` bytes: Content-Length is only a hint, so the stream itself is
# counted. Null when the body is too large.
async def readBodyText(request: any, limit: int) -> any {
    declared = globalThis.Number(either(request.headers.get("content-length"), 0));
    if globalThis.Number.isFinite(declared) and declared > limit {
        return NULL;
    } elif not request.body {
        return "";
    }
    (reader, chunks, size) = (request.body.getReader(), [], 0);
    while True {
        step = await reader.read();
        if step.done {
            return new(globalThis.TextDecoder).decode(
                await new(globalThis.Blob, chunks).arrayBuffer()
            );
        }
        size += step.value.byteLength;
        if size > limit {
            await reader.cancel().catch(lambda (e: any) -> any { None });
            return NULL;
        }
        chunks.append(step.value);
    }
}
