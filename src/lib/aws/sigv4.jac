glob:priv ENCODER: any = new(globalThis.TextEncoder),
          RESERVED: any = rx(r"[!'()*]", "g"),
          DATE_PUNCTUATION: any = rx(r"[:-]|\.\d{3}", "g"),
          SPACES: any = rx(r"\s+", "g");

def:priv hex_of(buffer: any) -> str {
    return "".join([
        byte.toString(16).padStart(2, "0")
        for byte in new(globalThis.Uint8Array, buffer)
    ]);
}

async def sha256Hex(data: any) -> str {
    octets = ENCODER.encode(data) if isinstance(data, str) else data;
    return hex_of(await globalThis.crypto.subtle.digest("SHA-256", octets));
}

async def:priv hmac(key: any, data: str) -> any {
    imported = await globalThis.crypto.subtle.importKey(
        "raw", key, {"name": "HMAC", "hash": "SHA-256"}, False, ["sign"]
    );
    return await globalThis.crypto.subtle.sign("HMAC", imported, ENCODER.encode(data));
}

def:priv rfc3986(value: str) -> str {
    return rx_sub(
        globalThis.encodeURIComponent(value),
        RESERVED,
        lambda (char: any) -> any { "%" + char.charCodeAt(0).toString(16).toUpperCase() },
    );
}

"""JavaScript's `<` on strings: UTF-16 code units. Jac's `<` orders by code point, which signs differently."""
def:priv code_unit_order(a: any, b: any) -> int {
    for i in range(globalThis.Math.min(a.length, b.length)) {
        gap = a.charCodeAt(i) - b.charCodeAt(i);
        if gap {
            return gap;
        }
    }
    return a.length - b.length;
}

def:priv by_name_then_value(a: any, b: any) -> int {
    return code_unit_order(a[0], b[0]) or code_unit_order(a[1], b[1]);
}

"""
AWS Signature Version 4. Returns the headers to send, including Authorization.
Web Crypto only, so it runs on Workers and in the Node build alike.
"""
async def signAwsRequest(input: any) -> any {
    (method, url, region, service, credentials) = (
        input["method"],
        input["url"],
        input["region"],
        input["service"],
        input["credentials"],
    );
    amz_date: str = rx_sub(
        either(at(input, "now"), new(globalThis.Date)).toISOString(), DATE_PUNCTUATION, ""
    );
    date_stamp = amz_date[:8];
    payload_hash = await sha256Hex(input["body"]);

    headers = merged(at(input, "headers", {}), {"host": url.host, "x-amz-date": amz_date});
    if service == "s3" {
        headers["x-amz-content-sha256"] = payload_hash;
    }
    if at(credentials, "sessionToken") {
        headers["x-amz-security-token"] = credentials["sessionToken"];
    }

    # Header names are unique once merged; equal lower-cased names keep their order (the sort is stable).
    normalized: any = [
        [name.toLowerCase(), rx_sub(value.trim(), SPACES, " ")]
        for (name, value) in entries(headers)
    ];
    normalized = globalThis.Array.prototype.sort.call(
        normalized, lambda (a: any, b: any) -> any { code_unit_order(a[0], b[0]) }
    );
    signed_headers = ";".join([name for (name, _) in normalized]);
    canonical_headers = "".join([f"{name}:{value}\n" for (name, value) in normalized]);

    # S3 signs the path as sent; every other service signs it percent-encoded twice.
    path: str = url.pathname or "/";
    canonical_path = path
        if service == "s3"
        else "/".join([
            rfc3986(globalThis.decodeURIComponent(segment))
            for segment in path.split("/")
        ]);
    query: any = [[rfc3986(name), rfc3986(value)] for (name, value) in url.searchParams.entries()];
    query = globalThis.Array.prototype.sort.call(query, by_name_then_value);
    canonical_query = "&".join([f"{name}={value}" for (name, value) in query]);

    canonical_request = "\n".join([
        method,
        canonical_path,
        canonical_query,
        canonical_headers,
        signed_headers,
        payload_hash,
    ]);
    scope = f"{date_stamp}/{region}/{service}/aws4_request";
    string_to_sign = "\n".join([
        "AWS4-HMAC-SHA256",
        amz_date,
        scope,
        await sha256Hex(canonical_request),
    ]);

    key: any = ENCODER.encode(f"AWS4{credentials['secretAccessKey']}");
    for part in [date_stamp, region, service, "aws4_request"] {
        key = await hmac(key, part);
    }
    signature = hex_of(await hmac(key, string_to_sign));

    return merged(
        headers,
        {
            "Authorization": f"AWS4-HMAC-SHA256 Credential={credentials['accessKeyId']}/{scope}, SignedHeaders={signed_headers}, Signature={signature}",
        },
    );
}
