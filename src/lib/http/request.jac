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
    reader = stream.getReader();
    chunks: list[any] = [];
    total = 0;
    while True {
        step = await reader.read();
        if step.done {
            break;
        }
        total += step.value.byteLength;
        if total > maxBytes {
            try {
                await reader.cancel();
            } except Exception {}
            raise RequestBodyTooLargeError("Request body is too large");
        }
        chunks.append(step.value);
    }
    body = new(globalThis.Uint8Array, total);
    offset = 0;
    for chunk in chunks {
        body.set(chunk, offset);
        offset += chunk.byteLength;
    }
    return body.buffer;
}

async def readJsonBody(request: any, maxBytes: any) -> any {
    body = await readRawBody(request, maxBytes);
    if body.byteLength == 0 {
        return globalThis.Object();
    }
    return globalThis.JSON.parse(new(globalThis.TextDecoder).decode(body));
}

def assertRequestSize(request: any, maxBytes: any) {
    if globalThis.Number(either(request.headers.get("content-length"), 0)) > maxBytes {
        raise RequestBodyTooLargeError("Request body is too large");
    }
}

async def readFormDataBody(request: any, maxBytes: any) -> any {
    body = await readRawBody(request, maxBytes);
    rebuilt = new(
        globalThis.Request,
        request.url,
        record({"method": request.method, "headers": request.headers, "body": body}),
    );
    return await rebuilt.formData();
}

"""Parses a JSON object body. `null` when the body is empty, malformed or not an object, so handlers can answer 400."""
async def readJsonObject(request: any) -> any {
    try {
        body = await request.json();
    } except Exception {
        return NULL;
    }
    is_object = bool(body)
        and globalThis.Object(body) is body
        and not globalThis.Array.isArray(body);
    return body if is_object else NULL;
}
