glob:priv js: any = globalThis.String,
          SANDBOX: str = "default-src 'none'; style-src 'unsafe-inline'; sandbox",
          FIXED: list[any] = [p.strip().split("=") for p in """Accept-Ranges=bytes
          |X-Content-Type-Options=nosniff|Referrer-Policy=no-referrer|Cache-Control=private, no-store""".split("|")];

"""Typed float: JavaScript arithmetic, which Jac's integers refuse past 2**53."""
def:priv number(v: any) -> float {
    return globalThis.Number(v);
}

"""One `bytes=` range: null when absent or unusable (multi-range is served whole), "invalid" when unsatisfiable."""
def parseByteRange(header: any, size: any) -> any {
    m = rx(r"^bytes=(\d*)-(\d*)$").exec(either(header.trim() if not nil(header) else None, ""));
    if nil(m) or (m[1] == "" and m[2] == "") {
        return NULL;
    }
    (n, a, b, suffix) = (number(size), number(m[1]), number(m[2]), m[1] == "");
    start = globalThis.Math.max(n - b, 0) if suffix else a;
    end = n - 1 if suffix or m[2] == "" else globalThis.Math.min(b, n - 1);
    bad = (suffix and b == 0) or start >= n or start > end;
    return "invalid" if bad else {"start": start, "end": end};
}

"""Streams a stored file with support for resumable downloads and seeking (`Range` / `If-Range`)."""
async def streamDriveFile(env: any, request: any, item: any, download: any) -> any {
    if item["kind"] != "file" {
        return new(globalThis.Response, "Not a file", record({"status": 400}));
    }
    # The uploader chooses the type, so HTML, SVG and anything unparsable download as opaque bytes.
    inline = NULL if download else getInlineContentType(item["contentType"]);
    (size, stamp) = (item["size"], item["updatedAt"].getTime().toString(36));
    etag = "\"" + js(item["id"]) + "-" + stamp + "-" + size.toString(36) + "\"";
    kind = either(inline, "application/octet-stream");
    # Chrome's PDF viewer breaks under a sandbox; a nosniff PDF runs no script, so framing is enough.
    csp = "frame-ancestors 'self'" if inline == "application/pdf" else SANDBOX;
    pairs: list[any] = [["Content-Type", kind], ["ETag", etag], ["Content-Security-Policy", csp]];
    named = driveContentDisposition(item["name"], inline is not NULL);
    headers = new(globalThis.Headers, FIXED + pairs + [["Content-Disposition", named]]);
    # A client resuming against a file that changed since must start over, which If-Range expresses.
    stale = request.headers.get("If-Range") not in [NULL, "", etag];
    rng = NULL if stale else parseByteRange(request.headers.get("Range"), size);
    if rng == "invalid" {
        headers.set("Content-Range", "bytes */" + js(size));
        return new(globalThis.Response, NULL, record({"status": 416, "headers": headers}));
    }
    key = either(item["r2Key"], driveObjectKey(item["ownerId"], item["id"]));
    (start, end) = (0.0, 0.0) if rng is NULL else (number(rng["start"]), number(rng["end"]));
    part = record({"range": record({"offset": start, "length": end - start + 1})});
    got = await (env.BUCKET.get(key) if rng is NULL else env.BUCKET.get(key, part));
    if not globalThis.Boolean(got) {
        return new(globalThis.Response, "File not found", record({"status": 404}));
    }
    if rng is not NULL {
        headers.set("Content-Range", f"bytes {js(start)}-{js(end)}/{js(size)}");
    }
    headers.set("Content-Length", js(size if rng is NULL else end - start + 1));
    (body, status) = (NULL if request.method == "HEAD" else got.body, 200 if rng is NULL else 206);
    return new(globalThis.Response, body, record({"status": status, "headers": headers}));
}
