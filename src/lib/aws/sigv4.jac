glob:priv ENC: any = new(globalThis.TextEncoder);

def:priv hex_of(buffer: any) -> str {
    return "".join([b.toString(16).padStart(2, "0") for b in new(globalThis.Uint8Array, buffer)]);
}

async def sha256Hex(data: any) -> str {
    octets = ENC.encode(data) if isinstance(data, str) else data;
    return hex_of(await globalThis.crypto.subtle.digest("SHA-256", octets));
}

async def:priv hmac(key: any, data: str) -> any {
    subtle = globalThis.crypto.subtle;
    k = await subtle.importKey("raw", key, {"name": "HMAC", "hash": "SHA-256"}, False, ["sign"]);
    return await subtle.sign("HMAC", k, ENC.encode(data));
}

def:priv rfc3986(v: str) -> str {
    hexed = lambda (c: any) -> any { "%" + c.charCodeAt(0).toString(16).toUpperCase() };
    return rx_sub(globalThis.encodeURIComponent(v), rx(r"[!'()*]", "g"), hexed);
}

"""JavaScript's `<` on strings (UTF-16 code units, as AWS signs); Jac's `<` orders by code point."""
def:priv cmp(a: any, b: any) -> int {
    return 0 if a == b else -1 if js_sort([a, b])[0] == a else 1;
}

"""AWS Signature Version 4 over Web Crypto: the headers to send, Authorization included."""
async def signAwsRequest(input: any) -> any {
    (url, region, service) = (input["url"], input["region"], input["service"]);
    (cred, now) = (input["credentials"], either(at(input, "now"), new(globalThis.Date)));
    amz: str = rx_sub(now.toISOString(), rx(r"[:-]|\.\d{3}", "g"), "");
    payload = await sha256Hex(input["body"]);
    headers = merged(at(input, "headers", {}), {"host": url.host, "x-amz-date": amz});
    if service == "s3" {
        headers["x-amz-content-sha256"] = payload;
    }
    if at(cred, "sessionToken") {
        headers["x-amz-security-token"] = cred["sessionToken"];
    }
    ws = rx(r"\s+", "g");
    norm: any = [[k.toLowerCase(), rx_sub(v.trim(), ws, " ")] for (k, v) in entries(headers)];
    norm = js_sort(norm, lambda (a: any, b: any) -> int { cmp(a[0], b[0]) });
    signed = ";".join([k for (k, _) in norm]);
    # S3 signs the path as sent; every other service signs it percent-encoded twice.
    path: str = url.pathname or "/";
    if service != "s3" {
        path = "/".join([rfc3986(globalThis.decodeURIComponent(s)) for s in path.split("/")]);
    }
    query: any = [[rfc3986(k), rfc3986(v)] for (k, v) in url.searchParams.entries()];
    query = js_sort(query, lambda (a: any, b: any) -> int { cmp(a[0], b[0]) or cmp(a[1], b[1]) });
    hs = "".join([f"{k}:{v}\n" for (k, v) in norm]);
    q = "&".join([f"{k}={v}" for (k, v) in query]);
    scope = f"{amz[:8]}/{region}/{service}/aws4_request";
    canonical = await sha256Hex("\n".join([input["method"], path, q, hs, signed, payload]));
    key: any = ENC.encode(f"AWS4{cred['secretAccessKey']}");
    for part in [amz[:8], region, service, "aws4_request"] {
        key = await hmac(key, part);
    }
    signature = hex_of(await hmac(key, "\n".join(["AWS4-HMAC-SHA256", amz, scope, canonical])));
    auth = f"{cred['accessKeyId']}/{scope}, SignedHeaders={signed}, Signature={signature}";
    return merged(headers, {"Authorization": f"AWS4-HMAC-SHA256 Credential={auth}"});
}
