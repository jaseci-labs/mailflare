# Every S3, B2 and SES request is signed here, so the path makes no closures, no tuples and no
# comprehensions, and calls JavaScript's own methods through `globalThis` (a direct call).
glob:priv ENC: any = new(globalThis.TextEncoder),
          HEX_DIGITS: str = "0123456789abcdef",
          AMZ_STRIP: any = rx(r"[:-]|\.\d{3}", "g"),
          SPACES: any = rx(r"\s+", "g"),
          RESERVED: any = rx(r"[!'()*]"),
          RESERVED_ALL: any = rx(r"[!'()*]", "g"),
          HMAC_SHA256: any = record({"name": "HMAC", "hash": "SHA-256"});

# `value.method()` as JavaScript calls it, for a value that is not a string.
def:priv js_call(o: any, name: str) -> any {
    return globalThis.Function.prototype.call.call(globalThis.Reflect.get(o, name), o);
}

def:priv hex_of(buffer: any) -> str {
    octets = new(globalThis.Uint8Array, buffer);
    if globalThis.Reflect.get(octets, "toHex") {
        return globalThis.Function.prototype.call.call(globalThis.Reflect.get(octets, "toHex"), octets);
    }
    out = "";
    for b in octets {
        out += HEX_DIGITS[b >> 4] + HEX_DIGITS[b & 15];
    }
    return out;
}

async def sha256Hex(data: any) -> str {
    octets = globalThis.TextEncoder.prototype.encode.call(ENC, data) if isinstance(data, str) else data;
    return hex_of(await globalThis.crypto.subtle.digest("SHA-256", octets));
}

async def:priv hmac(key: any, data: str) -> any {
    k = await globalThis.crypto.subtle.importKey("raw", key, HMAC_SHA256, False, ["sign"]);
    return await globalThis.crypto.subtle.sign("HMAC", k, globalThis.TextEncoder.prototype.encode.call(ENC, data));
}

def:priv hex_char(c: any) -> str {
    code = globalThis.String.prototype.charCodeAt.call(c, 0);
    return "%" + globalThis.String.prototype.toUpperCase.call(globalThis.Number.prototype.toString.call(code, 16));
}

def:priv rfc3986(v: any) -> str {
    encoded: str = globalThis.encodeURIComponent(v);
    if globalThis.RegExp.prototype.test.call(RESERVED, encoded) {
        return rx_sub(encoded, RESERVED_ALL, hex_char);
    }
    return encoded;
}

# A copy of an object's own entries, as `{...o}` makes it (nothing of null or undefined).
def:priv spread(o: any) -> any {
    if nil(o) {
        return globalThis.Object();
    }
    return globalThis.Object.fromEntries(globalThis.Object.entries(o));
}

# `xs` (strings) in JavaScript's default order: by UTF-16 code units, as AWS signs.
def:priv sorted_js(xs: list[str]) -> list[str] {
    return globalThis.Array.prototype.sort.call(xs);
}

"""AWS Signature Version 4 over Web Crypto: the headers to send, Authorization included."""
async def signAwsRequest(input: any) -> any {
    method = globalThis.Reflect.get(input, "method");
    url = globalThis.Reflect.get(input, "url");
    region = globalThis.Reflect.get(input, "region");
    service = globalThis.Reflect.get(input, "service");
    cred = globalThis.Reflect.get(input, "credentials");
    now = either(globalThis.Reflect.get(input, "now"), None);
    if now is None {
        now = new(globalThis.Date);
    }
    iso = globalThis.Reflect.apply(globalThis.Reflect.get(now, "toISOString"), now, []);
    amz: str = rx_sub(iso, AMZ_STRIP, "");
    stamp: str = globalThis.String.prototype.slice.call(amz, 0, 8);
    payload = await sha256Hex(globalThis.Reflect.get(input, "body"));
    headers = spread(globalThis.Reflect.get(input, "headers"));
    globalThis.Reflect.set(headers, "host", globalThis.Reflect.get(url, "host"));
    globalThis.Reflect.set(headers, "x-amz-date", amz);
    if service == "s3" {
        globalThis.Reflect.set(headers, "x-amz-content-sha256", payload);
    }
    token = globalThis.Reflect.get(cred, "sessionToken");
    if token {
        globalThis.Reflect.set(headers, "x-amz-security-token", token);
    }
    # Sorted by name, a stable sort: names in order, each name's values in the order they came.
    by_name: dict[str, list[str]] = {};
    names: list[str] = [];
    for name in globalThis.Object.keys(headers) {
        value = globalThis.Reflect.get(headers, name);
        if isinstance(value, str) {
            value = globalThis.String.prototype.trim.call(value);
        } else {
            value = js_call(value, "trim");
        }
        value = rx_sub(value, SPACES, " ");
        lower: str = globalThis.String.prototype.toLowerCase.call(name);
        values = by_name.get(lower);
        if values is None {
            values = [];
            by_name[lower] = values;
            names.append(lower);
        }
        values.append(value);
    }
    signed_names: list[str] = [];
    lines: list[str] = [];
    for name in sorted_js(names) {
        for value in by_name[name] {
            signed_names.append(name);
            lines.append(name + ":" + value + "\n");
        }
    }
    signed = ";".join(signed_names);
    # S3 signs the path as sent; every other service signs it percent-encoded twice.
    path = globalThis.Reflect.get(url, "pathname") or "/";
    if service != "s3" {
        segments: list[str] = [];
        for segment in globalThis.String.prototype.split.call(path, "/") {
            segments.append(rfc3986(globalThis.decodeURIComponent(segment)));
        }
        path = "/".join(segments);
    }
    # Sorted by name, then value: equal pairs are the same text, so the order of each name's
    # values is their own sorted order.
    params = globalThis.Reflect.get(url, "searchParams");
    by_key: dict[str, list[str]] = {};
    keys: list[str] = [];
    for key in globalThis.Array.from(globalThis.URLSearchParams.prototype.keys.call(params)) {
        keys.append(rfc3986(key));
    }
    i: int = 0;
    for raw in globalThis.Array.from(globalThis.URLSearchParams.prototype.values.call(params)) {
        key = keys[i];
        i += 1;
        values = by_key.get(key);
        if values is None {
            values = [];
            by_key[key] = values;
        }
        values.append(rfc3986(raw));
    }
    pairs: list[str] = [];
    for key in sorted_js(list(by_key.keys())) {
        for value in sorted_js(by_key[key]) {
            pairs.append(key + "=" + value);
        }
    }
    scope = stamp + "/" + globalThis.String(region) + "/" + globalThis.String(service) + "/aws4_request";
    request = globalThis.Array.prototype.join.call(
        [method, path, "&".join(pairs), "".join(lines), signed, payload],
        "\n",
    );
    canonical = await sha256Hex(request);
    secret = globalThis.String.prototype.concat.call("AWS4", globalThis.Reflect.get(cred, "secretAccessKey"));
    key: any = globalThis.TextEncoder.prototype.encode.call(ENC, secret);
    key = await hmac(key, stamp);
    key = await hmac(key, region);
    key = await hmac(key, service);
    key = await hmac(key, "aws4_request");
    to_sign = "AWS4-HMAC-SHA256\n" + amz + "\n" + scope + "\n" + canonical;
    signature = hex_of(await hmac(key, to_sign));
    credential = globalThis.String.prototype.concat.call("", globalThis.Reflect.get(cred, "accessKeyId"), "/", scope);
    out = spread(headers);
    auth = "AWS4-HMAC-SHA256 Credential=" + credential + ", SignedHeaders=" + signed + ", Signature=" + signature;
    globalThis.Reflect.set(out, "Authorization", auth);
    return out;
}
