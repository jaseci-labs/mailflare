glob:priv META: str = "x-amz-meta-",
          UNSAFE: any = rx(r"[!'()*]", "g"),
          FIELDS: any = [p.split("=") for p in """Content-Type=contentType
              Content-Disposition=contentDisposition Cache-Control=cacheControl""".split()],
          # JavaScript callers chain `.catch` and fire and forget: these return real promises.
          ASYNC: any = "get head put delete list createMultipartUpload".split(),
          METHODS: any = "arrayBuffer text json blob".split();

def:priv fail(when: any, message: any) -> any {
    if when {
        raise new(globalThis.Error, message);
    }
}

"""The URL parser resolves `.` and `..` segments, so such a key would be sent as a different key."""
def:priv encode_path(key: any) -> str {
    parts = key.split("/");
    fail(any([part in (".", "..") for part in parts]), "Object key has a . or .. segment");
    hex = lambda (c: any) -> any { "%" + c.charCodeAt(0).toString(16).toUpperCase() };
    return "/" + "/".join([rx_sub(globalThis.encodeURIComponent(p), UNSAFE, hex) for p in parts]);
}

async def:priv to_buffer(value: any) -> any {
    # Response reads every other body the original took (null, string, view, Blob, stream) as it did.
    keep = isinstance(value, globalThis.ArrayBuffer);
    return value if keep else await new(globalThis.Response, value).arrayBuffer();
}

def:priv http_metadata(headers: any) -> any {
    return merged({k: either(headers.get(name), None) for (name, k) in FIELDS});
}

def:priv etag_of(headers: any) -> str {
    return either(headers.get("etag"), "").replace('"', "");
}

def:priv stamp(when: any) -> any {
    return new(globalThis.Date, either(when, globalThis.Date.now()));
}

def:priv part_xml(p: any) -> str {
    etag = p["etag"].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    return f'<Part><PartNumber>{globalThis.String(p["partNumber"])}</PartNumber><ETag>"{etag}"</ETag></Part>';
}

def:priv listed(b: any) -> any {
    (key, size, when) = (xmlTag(b, "Key"), xmlTag(b, "Size"), xmlTag(b, "LastModified"));
    return record({
        "key": key,
        "size": globalThis.Number(either(size, 0)),
        "uploaded": stamp(when),
    });
}

def:priv eager(f: any) -> any {
    return lambda (*a: any) -> any { promise(f(*a)) };
}

obj B2Object(globalThis.Object) {
    def init(key: any, response: any, size: any = None) {
        super.init();
        (self.key, self.response, hs) = (key, response, response.headers);
        ranged = rx(r"\/(\d+)$").exec(either(hs.get("content-range"), ""));
        total = ranged[1] if ranged else hs.get("content-length");
        self.size = either(size, globalThis.Number(either(total, 0)));
        (self.etag, self.uploaded) = (etag_of(hs), stamp(hs.get("last-modified")));
        self.httpMetadata = http_metadata(hs);
        pairs = globalThis.Array.from(hs.entries());
        self.customMetadata = record({n[len(META):]: v for (n, v) in pairs if n.startswith(META)});
        # Getters and methods in the original: none is an own enumerable key.
        get = lambda (f: any) -> any { record({"get": f}) };
        props = {
            "httpEtag": get(lambda -> any { f'"{self.etag}"' }),
            "version": get(lambda -> any { self.etag }),
            "body": get(lambda -> any { response.body or new(globalThis.Blob, []).stream() }),
            "bodyUsed": get(lambda -> any { response.bodyUsed }),
            **{n: record({"value": response[n].bind(response)}) for n in METHODS},
        };
        globalThis.Object.defineProperties(self, record(props));
    }

    def writeHttpMetadata(headers: any) -> any {
        [headers.set(h, self.httpMetadata[k]) for (h, k) in FIELDS if at(self.httpMetadata, k)];
    }
}

obj B2Bucket(globalThis.Object) {
    def init(config: any) {
        super.init();
        self.config = config;
        (key, secret) = (config["keyId"], config["applicationKey"]);
        auth = {"accessKeyId": key, "secretAccessKey": secret, "region": config["region"]};
        (self.credentials, self.host) = (record(auth), f"{config['bucket']}.{config['endpoint']}");
        prop = lambda (n: str) -> any { record({"value": eager(getattr(self, n))}) };
        globalThis.Object.defineProperties(self, record({n: prop(n) for n in ASYNC}));
    }

    async def request(key: any, req: any = None) -> any {
        path = "/" if key is NULL else encode_path(key);
        base = {"config": self.credentials, "service": "s3", "host": self.host, "path": path};
        return await awsRequest(merged(base, either(req, {})));
    }

    def meta_headers(options: any) -> any {
        meta = at(options, "httpMetadata");
        http = http_metadata(meta) if isinstance(meta, globalThis.Headers) else either(meta, {});
        custom = {META + n.lower(): v for (n, v) in entries(at(options, "customMetadata", {}))};
        return record({**{h: http[k] for (h, k) in FIELDS if at(http, k)}, **custom});
    }

    async def found(key: any, req: any, code: str, status: int) -> any {
        response = await awsSpare(self.request(key, req), code, status);
        return NULL if response is None else B2Object(key, response);
    }

    async def get(key: any, options: any = None) -> any {
        span = at(options, "range");
        (start, n, tail) = (at(span, "offset", 0), at(span, "length"), at(span, "suffix"));
        bounds = f"-{tail}"
            if not nil(tail)
            else f"{start}-" + ("" if nil(n) else f"{start + n - 1}");
        headers = record({"Range": f"bytes={bounds}"} if span else {});
        return await self.found(key, {"headers": headers}, "NoSuchKey", 404);
    }

    async def head(key: any) -> any {
        return await self.found(key, {"method": "HEAD"}, "", 404);
    }

    async def put(key: any, value: any, options: any = None) -> any {
        body = await to_buffer(value);
        req = {"method": "PUT", "body": body, "headers": self.meta_headers(options)};
        stub = record({"headers": (await self.request(key, req)).headers});
        return B2Object(key, new(globalThis.Response, NULL, stub), body.byteLength);
    }

    async def delete(keys: any) -> any {
        keys = keys if globalThis.Array.isArray(keys) else [keys];
        drop = lambda (k: any) -> any { awsSpare(self.request(k, {"method": "DELETE"}), "", 404) };
        for i in range(0, len(keys), 10) {
            await globalThis.Promise.all([drop(k) for k in keys[i:i + 10]]);
        }
    }

    """ListObjectsV2 with the shape of R2's `list`: only key, size and upload time of each object."""
    async def `list(options: any = None) -> any {
        limit = globalThis.String(globalThis.Math.min(at(options, "limit", 1000), 1000));
        extra = [("prefix", at(options, "prefix")), ("continuation-token", at(options, "cursor"))];
        query = {"list-type": "2", "max-keys": limit, **{k: v for (k, v) in extra if v}};
        xml = await (await self.request(NULL, {"query": record(query)})).text();
        objects = [listed(b) for b in xmlBlocks(xml, "Contents") if xmlTag(b, "Key")];
        truncated = xmlTag(xml, "IsTruncated") == "true";
        token = either(xmlTag(xml, "NextContinuationToken"), None) if truncated else None;
        return merged({"objects": objects, "truncated": truncated, "cursor": token});
    }

    async def createMultipartUpload(key: any, options: any = None) -> any {
        q = record({"uploads": ""});
        req = {"method": "POST", "query": q, "headers": self.meta_headers(options)};
        uploadId = xmlTag(await (await self.request(key, req)).text(), "UploadId");
        fail(not uploadId, "Backblaze did not return an upload id");
        return self.resumeMultipartUpload(key, uploadId);
    }

    def resumeMultipartUpload(key: any, uploadId: any) -> any {
        query = record({"uploadId": uploadId});
        async def part(n: any, value: any = None) -> any {
            fail(not whole(n, 1), "Invalid part number");
            q = record({"partNumber": globalThis.String(n), "uploadId": uploadId});
            body = await to_buffer(value);
            response = await self.request(key, {"method": "PUT", "query": q, "body": body});
            return record({"partNumber": n, "etag": etag_of(response.headers)});
        }
        async def abort -> any {
            await self.request(key, {"method": "DELETE", "query": query});
        }
        async def complete(parts: any) -> any {
            num = lambda (p: any) -> any { globalThis.Number(p["partNumber"]) };
            ordered = js_sort([*parts], lambda (a: any, b: any) -> any { num(a) - num(b) });
            inner = "".join([part_xml(p) for p in ordered]);
            body = f"<CompleteMultipartUpload>{inner}</CompleteMultipartUpload>";
            hs = record({"Content-Type": "application/xml"});
            req = {"method": "POST", "query": query, "body": body, "headers": hs};
            # A 200 can still carry an <Error> document.
            text = await (await self.request(key, req)).text();
            why = either(xmlTag(text, "Message"), "Multipart upload failed");
            fail(rx("<Error>").test(text), why);
            head = await self.head(key);
            fail(not head, "Uploaded object not found");
            return head;
        }
        fns = {"uploadPart": eager(part), "abort": eager(abort), "complete": eager(complete)};
        return record({"key": key, "uploadId": uploadId, **fns});
    }
}

def openB2Bucket(config: any) -> any {
    return B2Bucket(config);
}
