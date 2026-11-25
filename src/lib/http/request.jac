"""
Reads a request body without ever buffering more than maxBytes. A declared Content-Length over the
cap is refused up front; chunked or understated bodies are cut off as soon as the cap is crossed.
"""
async def readRawBody(request: any, maxBytes: any) -> any {
    assertRequestSize(request, maxBytes);
    stream = at(request, "body");
    if not stream {
        return new(globalThis.ArrayBuffer, 0);
    }
    (reader, total) = (stream.getReader(), 0);
    chunks: list[any] = [];
    while not (step := await reader.read()).done {
        total += step.value.byteLength;
        if total > maxBytes {
            await reader.cancel().catch(lambda (e: any) -> any { None });
            raise RequestBodyTooLargeError("Request body is too large");
        }
        chunks.append(step.value);
    }
    return await new(globalThis.Blob, chunks).arrayBuffer();
}

async def readJsonBody(request: any, maxBytes: any) -> any {
    body = await readRawBody(request, maxBytes);
    text = new(globalThis.TextDecoder).decode(body);
    return globalThis.JSON.parse(text) if body.byteLength else globalThis.Object();
}

def assertRequestSize(request: any, maxBytes: any) {
    if globalThis.Number(either(request.headers.get("content-length"), 0)) > maxBytes {
        raise RequestBodyTooLargeError("Request body is too large");
    }
}

async def readFormDataBody(request: any, maxBytes: any) -> any {
    body = await readRawBody(request, maxBytes);
    init = {"method": request.method, "headers": request.headers, "body": body};
    return await new(globalThis.Request, request.url, record(init)).formData();
}

"""Parses a JSON object body; null when it is empty, malformed or not an object (a 400)."""
async def readJsonObject(request: any) -> any {
    body = await request.json().catch(lambda (e: any) -> any { NULL });
    return body if is_object(body) and not globalThis.Array.isArray(body) else NULL;
}
