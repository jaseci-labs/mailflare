# The slice of R2's bucket API the app uses, served by Backblaze B2 or AWS S3 over the S3 API.
glob:priv META: str = "x-amz-meta-",
          FIELDS: any = [p.split("=") for p in """Content-Type=contentType
              Content-Disposition=contentDisposition Cache-Control=cacheControl""".split()],
          # JavaScript callers chain `.catch` and fire and forget: these return real promises.
          ASYNC: any = "get head put delete list createMultipartUpload".split();

"""The URL parser resolves `.` and `..` segments, so such a key would be sent as a different key."""
def:priv assert_plain(key: any) -> any {
    if any([part in (".", "..") for part in key.split("/")]) {
        raise new(globalThis.Error, "Object key has a . or .. segment");
    }
}

def:priv encode_path(key: any) -> str {
    hex = lambda (c: any) -> any { "%" + c.charCodeAt(0).toString(16).toUpperCase() };
    esc = lambda (p: any) -> str {
        rx_sub(globalThis.encodeURIComponent(p), rx(r"[!'()*]", "g"), hex)
    };
    return "/" + "/".join([esc(part) for part in key.split("/")]);
}

async def:priv to_buffer(value: any) -> any {
    if value is NULL or isinstance(value, str) {
        return new(globalThis.TextEncoder).encode("" if value is NULL else value).buffer;
    }
    if isinstance(value, globalThis.ArrayBuffer) {
        return value;
    }
    if globalThis.ArrayBuffer.isView(value) {
        return value.buffer.slice(value.byteOffset, value.byteOffset + value.byteLength);
    }
    source = value if isinstance(value, globalThis.Blob) else new(globalThis.Response, value);
    return await source.arrayBuffer();
}

def:priv http_metadata(headers: any) -> any {
    return merged({k: either(headers.get(name), None) for (name, k) in FIELDS});
}

def:priv etag_of(headers: any) -> str {
    return either(headers.get("etag"), "").replace('"', "");
}

obj B2Object(globalThis.Object) {
    def init(key: any, response: any, size: any = None) {
        super.init();
        (self.key, self.response, hs) = (key, response, response.headers);
        ranged = rx(r"\/(\d+)$").exec(either(hs.get("content-range"), ""));
        total = ranged[1] if ranged else hs.get("content-length");
        self.size = either(size, globalThis.Number(either(total, 0)));
        self.etag = etag_of(hs);
        self.uploaded = new(
            globalThis.Date, either(hs.get("last-modified"), globalThis.Date.now())
        );
        self.httpMetadata = http_metadata(hs);
        pairs = globalThis.Array.from(hs.entries());
        self.customMetadata = record({n[len(META):]: v for (n, v) in pairs if n.startswith(META)});
        # Getters and methods in the original: none is an own enumerable key.
        get = lambda (f: any) -> any { record({"get": f}) };
        empty = lambda -> any { new(globalThis.Blob, []).stream() };
        props = {
            "httpEtag": get(lambda -> any { f'"{self.etag}"' }),
            "version": get(lambda -> any { self.etag }),
            "body": get(lambda -> any { empty() if nil(response.body) else response.body }),
            "bodyUsed": get(lambda -> any { response.bodyUsed }),
        };
        for name in "arrayBuffer text json blob".split() {
            props[name] = record({"value": response[name].bind(response)});
        }
        globalThis.Object.defineProperties(self, record(props));
    }

    def writeHttpMetadata(headers: any) -> any {
        for (name, k) in FIELDS {
            if at(self.httpMetadata, k) {
                headers.set(name, self.httpMetadata[k]);
            }
        }
    }
}

obj B2Bucket(globalThis.Object) {
    def init(config: any) {
        super.init();
        self.config = config;
        (key, secret) = (config["keyId"], config["applicationKey"]);
        auth = {"accessKeyId": key, "secretAccessKey": secret, "region": config["region"]};
        (self.credentials, self.host) = (record(auth), f"{config['bucket']}.{config['endpoint']}");
        for name in ASYNC {
            globalThis.Object.defineProperty(
                self, name, record({"value": promised(getattr(self, name))})
            );
        }
    }

    def request(key: any, req: any = None) -> any {
        if key is not NULL {
            assert_plain(key);
        }
        path = "/" if key is NULL else encode_path(key);
        base = {"config": self.credentials, "service": "s3", "host": self.host, "path": path};
        return awsRequest(merged(base, either(req, {})));
    }

    def meta_headers(options: any) -> any {
        meta = at(options, "httpMetadata");
        http = http_metadata(meta) if isinstance(meta, globalThis.Headers) else either(meta, {});
        out = {name: http[k] for (name, k) in FIELDS if at(http, k)};
        for (name, value) in entries(at(options, "customMetadata", {})) {
            out[META + name.lower()] = value;
        }
        return record(out);
    }

    async def found(key: any, req: any, code: str, status: int) -> any {
        response = await awsSpare(self.request(key, req), code, status);
        return NULL if response is None else B2Object(key, response);
    }

    async def get(key: any, options: any = None) -> any {
        (span, headers) = (at(options, "range"), {});
        if span and not nil(at(span, "suffix")) {
            headers["Range"] = f"bytes=-{span['suffix']}";
        } elif span {
            (start, n) = (at(span, "offset", 0), at(span, "length"));
            headers["Range"] = f"bytes={start}-" + ("" if nil(n) else f"{start + n - 1}");
        }
        return await self.found(key, {"headers": record(headers)}, "NoSuchKey", 404);
    }

    async def head(key: any) -> any {
        return await self.found(key, {"method": "HEAD"}, "", 404);
    }

    async def put(key: any, value: any, options: any = None) -> any {
        body = await to_buffer(value);
        req = {"method": "PUT", "body": body, "headers": self.meta_headers(options)};
        response = await self.request(key, req);
        stub = new(globalThis.Response, NULL, record({"headers": response.headers}));
        return B2Object(key, stub, body.byteLength);
    }

    async def remove(key: any) -> any {
        await awsSpare(self.request(key, {"method": "DELETE"}), "", 404);
    }

    async def delete(keys: any) -> any {
        keys = keys if globalThis.Array.isArray(keys) else [keys];
        for i in range(0, len(keys), 10) {
            await globalThis.Promise.all([self.remove(key) for key in keys[i:i + 10]]);
        }
    }

    """ListObjectsV2 with the shape of R2's `list`: only key, size and upload time of each object."""
    async def `list(options: any = None) -> any {
        limit = globalThis.String(globalThis.Math.min(at(options, "limit", 1000), 1000));
        (prefix, cursor) = (at(options, "prefix"), at(options, "cursor"));
        query = {"list-type": "2", "max-keys": limit};
        query = {
            **query,
            **{k: v for (k, v) in [("prefix", prefix), ("continuation-token", cursor)] if v},
        };
        xml = await (await self.request(NULL, {"query": record(query)})).text();
        objects = [
            record({
                "key": either(xmlTag(block, "Key"), ""),
                "size": globalThis.Number(either(xmlTag(block, "Size"), 0)),
                "uploaded": new(
                    globalThis.Date, either(xmlTag(block, "LastModified"), globalThis.Date.now())
                ),
            })
            for block in xmlBlocks(xml, "Contents")
        ];
        truncated = xmlTag(xml, "IsTruncated") == "true";
        token = either(xmlTag(xml, "NextContinuationToken"), None) if truncated else None;
        return merged({
            "objects": [o for o in objects if o.key],
            "truncated": truncated,
            "cursor": token,
        });
    }

    async def createMultipartUpload(key: any, options: any = None) -> any {
        req = {
            "method": "POST",
            "query": record({"uploads": ""}),
            "headers": self.meta_headers(options),
        };
        uploadId = xmlTag(await (await self.request(key, req)).text(), "UploadId");
        if not uploadId {
            raise new(globalThis.Error, "Backblaze did not return an upload id");
        }
        return self.resumeMultipartUpload(key, uploadId);
    }

    def resumeMultipartUpload(key: any, uploadId: any) -> any {
        query = record({"uploadId": uploadId});
        async def part(n: any, value: any) -> any {
            if not whole(n, 1) {
                raise new(globalThis.Error, "Invalid part number");
            }
            q = record({"partNumber": globalThis.String(n), "uploadId": uploadId});
            response = await self.request(
                key, {"method": "PUT", "query": q, "body": await to_buffer(value)}
            );
            return record({"partNumber": n, "etag": etag_of(response.headers)});
        }
        async def abort -> any {
            await self.request(key, {"method": "DELETE", "query": query});
        }
        async def complete(parts: any) -> any {
            num = lambda (p: any) -> any { globalThis.Number(p["partNumber"]) };
            ordered = js_sort([*parts], lambda (a: any, b: any) -> any { num(a) - num(b) });
            xml = [
                f'<Part><PartNumber>{globalThis.String(p["partNumber"])}</PartNumber><ETag>"{escape(p["etag"])}"</ETag></Part>'
                for p in ordered
            ];
            body = f"<CompleteMultipartUpload>{''.join(xml)}</CompleteMultipartUpload>";
            hs = record({"Content-Type": "application/xml"});
            response = await self.request(
                key, {"method": "POST", "query": query, "body": body, "headers": hs}
            );
            # A 200 can still carry an <Error> document.
            text = await response.text();
            if rx("<Error>").test(text) {
                raise new(
                    globalThis.Error, either(xmlTag(text, "Message"), "Multipart upload failed")
                );
            }
            head = await self.head(key);
            if not head {
                raise new(globalThis.Error, "Uploaded object not found");
            }
            return head;
        }
        return record({
            "key": key,
            "uploadId": uploadId,
            "uploadPart": lambda (n: any = None, v: any = None) -> any { promise(part(n, v)) },
            "abort": lambda -> any { promise(abort()) },
            "complete": lambda (parts: any = None) -> any { promise(complete(parts)) },
        });
    }
}

def:priv promised(f: any) -> any {
    return lambda (*a: any) -> any { promise(f(*a)) };
}

def:priv escape(value: any) -> any {
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
}

def openB2Bucket(config: any) -> any {
    return B2Bucket(config);
}
