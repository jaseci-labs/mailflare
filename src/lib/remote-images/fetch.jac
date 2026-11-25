glob REMOTE_IMAGE_MAX_URL_LENGTH: int = 4096,
     REMOTE_IMAGE_MAX_BYTES: int = 5 * 1024 * 1024,
     REMOTE_IMAGE_MAX_REDIRECTS: int = 3,
     REMOTE_IMAGE_TIMEOUT_MS: int = 10000;

# BLOCKED bars each name and its subdomains; the first seven are wildcard DNS services that
# resolve an embedded address, e.g. 127.0.0.1.nip.io.
glob:priv REDIRECTS: any = [301, 302, 303, 307, 308],
          ALLOWED: any = "image/png image/jpeg image/gif image/webp image/avif".split(),
          # Each matches the first 12 bytes, as Latin-1, of an ALLOWED type but avif.
          SIGNATURES: any = r"^\x89PNG\r\n\x1a\n ^\xff\xd8\xff ^GIF8[79]a ^RIFF[\s\S]{4}WEBP".split(),
          ACCEPT: str = "image/png,image/jpeg,image/gif,image/webp,image/avif",
          BLOCKED: any = """nip.io sslip.io xip.io traefik.me localtest.me lvh.me localhost.run
              localhost local internal test home.arpa""".split();

obj RemoteImageError(globalThis.Error) {
    def init(message: any, status: any, code: any) {
        super.init(message);
        (self.status, self.code, self.name) = (status, code, "RemoteImageError");
        # Jac's raise sets `__cause__`: keep it out of the keys JavaScript sees, as in the original.
        globalThis.Object.defineProperty(self, "__cause__", record({"writable": True}));
    }
}

def:priv fail(when: any, message: str, status: int, code: str) -> any {
    if when {
        raise RemoteImageError(message, status, code);
    }
}

def:priv bad(when: any, message: str = "Invalid remote image URL") -> any {
    fail(when, message, 400, "invalid_url");
}

async def:priv drop(stream: any) -> any {
    if not nil(stream) {
        await stream.cancel().catch(lambda (e: any) -> any { None });
    }
}

async def:priv refuse(when: any, stream: any, message: str, status: int, code: str) -> any {
    if when {
        await drop(stream);
        fail(True, message, status, code);
    }
}

def isIpLiteral(hostname: str) -> bool {
    return hostname.startswith("[") or rx(r"^\d{1,3}(?:\.\d{1,3}){3}$").test(hostname);
}

def isForbiddenHostname(hostname: str) -> bool {
    host = hostname.lower().removesuffix(".");
    dotted = rx(r"(?<![\d])(\d{1,3})[.-](\d{1,3})[.-](\d{1,3})[.-](\d{1,3})(?![\d])", "g");
    found: any = globalThis.Array.from(globalThis.String.prototype.matchAll.call(host, dotted));
    private = lambda (m: any) -> bool { not isPublicIpv4(f"{m[1]}.{m[2]}.{m[3]}.{m[4]}") };
    return found.some(private) or any([host == s or host.endswith("." + s) for s in BLOCKED]);
}

def parseRemoteImageUrl(value: any, blockedOrigins: any = None) -> any {
    fits = value and len(value) <= REMOTE_IMAGE_MAX_URL_LENGTH;
    url = globalThis.URL.parse(value) if fits else NULL;
    bad(not url or url.protocol not in ("http:", "https:"));
    bad(url.username or url.password or url.port);
    host = url.hostname;
    bad(not host or isIpLiteral(host) or isForbiddenHostname(host));
    origins = globalThis.Array.from([] if blockedOrigins is None else blockedOrigins);
    bad(url.origin in origins, "Remote image URL cannot target this application");
    return url;
}

def:priv ascii(b: any, start: int, length: int) -> str {
    return globalThis.String.fromCharCode.apply(None, b.subarray(start, start + length));
}

def:priv signed(kind: str, b: any) -> bool {
    if kind != "image/avif" {
        return rx(SIGNATURES[ALLOWED.index(kind)]).test(ascii(b, 0, 12));
    }
    if b.length < 16 or ascii(b, 4, 4) != "ftyp" {
        return False;
    }
    view = new(globalThis.DataView, b.buffer, b.byteOffset);
    box = globalThis.Math.min(b.length, view.getUint32(0));
    return box >= 16 and any(ascii(b, o, 4) in ("avif", "avis") for o in range(8, box - 3, 4));
}

async def:priv read_limited(res: any, maxBytes: any) -> any {
    declared = globalThis.Number(res.headers.get("content-length"));
    big = globalThis.Number.isFinite(declared) and declared > maxBytes;
    await refuse(big, res.body, "Remote image is too large", 413, "too_large");
    fail(not res.body, "Remote image has no body", 502, "empty_body");
    reader = res.body.getReader();
    (chunks, size) = ([], 0);
    try {
        step = await reader.read();
        while not step.done {
            size += step.value.byteLength;
            await refuse(size > maxBytes, reader, "Remote image is too large", 413, "too_large");
            chunks.append(step.value);
            step = await reader.read();
        }
    } except Exception as caught {
        c: any = caught;
        await drop(reader);
        raise getattr(c, "js", c);
    }
    (body, offset) = (new(globalThis.Uint8Array, size), 0);
    for chunk in chunks {
        body.set(chunk, offset);
        offset += chunk.byteLength;
    }
    return body;
}

"""Any textual IPv6 form (compressed, mixed dotted tail, zone id) as 8 groups, or null if malformed."""
def:priv parse_ipv6(input: str) -> any {
    value = input.split("%", 1)[0];
    tail = rx(r"(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$").exec(value);
    if tail {
        o = [globalThis.Number(tail[i]) for i in range(1, 5)];
        if any([octet > 255 for octet in o]) {
            return NULL;
        }
        hi: any = (o[0] << 8) | o[1];
        lo: any = (o[2] << 8) | o[3];
        value = f"{value[:tail.index]}{hi.toString(16)}:{lo.toString(16)}";
    }
    halves = value.split("::");
    groups: any = [[] if part == "" else part.split(":") for part in halves];
    (missing, two) = (8 - sum([len(part) for part in groups]), len(halves) == 2);
    if len(halves) > 2 or ((missing < 1) if two else (missing != 0)) {
        return NULL;
    }
    groups = groups[0] + ["0"] * missing + groups[1] if two else groups[0];
    ok = len(groups) == 8 and all([rx(r"^[0-9a-f]{1,4}$").test(group) for group in groups]);
    return [globalThis.parseInt(group, 16) for group in groups] if ok else NULL;
}

def isPublicAddress(address: any) -> bool {
    value: any = address.trim().toLowerCase();
    if ":" not in value {
        return isPublicIpv4(value);
    }
    g = parse_ipv6(value);
    if not g {
        return False;
    }
    v4 = lambda (h: int, l: int) -> bool { isPublicIpv4(f"{h >> 8}.{h & 255}.{l >> 8}.{l & 255}") };
    # IPv4-mapped (::ffff:0:0/96) and IPv4-compatible (::/96, also :: and ::1) take the IPv4's verdict.
    if all([x == 0 for x in g[:5]]) and (g[5] == 0xffff or g[5] == 0) {
        return v4(g[6], g[7]);
    }
    # NAT64 (64:ff9b::/96) and 6to4 (2002::/16) carry an IPv4; local-use NAT64 (64:ff9b:1::/48) never.
    if g[0] == 0x64 and g[1] == 0xff9b {
        return all([x == 0 for x in g[2:6]]) and v4(g[6], g[7]);
    }
    if g[0] == 0x2002 {
        return v4(g[1], g[2]);
    }
    # Other 0000::/8 is reserved; then unique local fc00::/7, link/site-local fe80::/10, fec0::/10, ff00::/8.
    return (g[0] >> 8) not in (0, 0xfc, 0xfd, 0xfe, 0xff);
}

async def:priv resolve_default(hostname: any) -> any {
    (v4, v6) = await globalThis.Promise.all([queryDns(hostname, "A"), queryDns(hostname, "AAAA")]);
    return [*v4, *v6];
}

"""A public-looking name can still resolve to a private address, so check what it resolves to."""
async def:priv assert_public(resolve: any, hostname: any) -> any {
    try {
        found: any = await resolve(hostname);
    } except Exception {
        fail(True, "Could not verify remote image host", 502, "upstream_error");
    }
    ok = found.length and found.every(lambda (a: any) -> bool { isPublicAddress(a) });
    bad(not ok, "Remote image host is not public");
}

async def fetchRemoteImage(value: any, options: any = None) -> any {
    o: any = {} if options is None else options;
    (fetcher, resolve) = (at(o, "fetch", globalThis.fetch), at(o, "resolveHost", resolve_default));
    blocked = globalThis.Array.from(at(o, "blockedOrigins", []));
    maxBytes = at(o, "maxBytes", REMOTE_IMAGE_MAX_BYTES);
    hops = at(o, "maxRedirects", REMOTE_IMAGE_MAX_REDIRECTS);
    current = parseRemoteImageUrl(value, blocked);
    controller = new(globalThis.AbortController);
    ms = at(o, "timeoutMs", REMOTE_IMAGE_TIMEOUT_MS);
    timeout = globalThis.setTimeout(lambda -> any { controller.abort() }, ms);
    hs = record({"Accept": ACCEPT, "User-Agent": "Mailflare-Remote-Images/1.0"});
    base = {"method": "GET", "headers": hs, "cache": "no-store", "redirect": "manual"};
    init = record({**base, "signal": controller.signal});
    try {
        redirects = 0;
        while True {
            await assert_public(resolve, current.hostname);
            try {
                res = await fetcher(current.href, init);
            } except Exception {
                fail(controller.signal.aborted, "Remote image request timed out", 504, "timeout");
                fail(True, "Could not fetch remote image", 502, "upstream_error");
            }
            if res.status in REDIRECTS {
                await drop(res.body);
                fail(
                    redirects >= hops, "Too many remote image redirects", 502, "too_many_redirects"
                );
                location = res.headers.get("location");
                fail(
                    not location, "Remote image redirect has no location", 502, "invalid_redirect"
                );
                moved = globalThis.URL.parse(location, current);
                fail(not moved, "Remote image redirect is invalid", 502, "invalid_redirect");
                (current, redirects) = (parseRemoteImageUrl(moved.href, blocked), redirects + 1);
                continue;
            }
            await refuse(
                not res.ok,
                res.body,
                "Remote image server returned an error",
                502,
                "upstream_status",
            );
            received: any = res.headers.get("content-type");
            kind: any = "" if not received else received.split(";", 1)[0].trim().toLowerCase();
            shown = either(received, "missing content type").split(";", 1)[0][:100];
            why = f"Remote resource is not a supported image ({shown})";
            await refuse(kind not in ALLOWED, res.body, why, 415, "unsupported_type");
            try {
                body = await read_limited(res, maxBytes);
            } except Exception as caught {
                c: any = caught;
                e: any = getattr(c, "js", c);
                late = controller.signal.aborted and not isinstance(e, RemoteImageError);
                fail(late, "Remote image request timed out", 504, "timeout");
                raise e;
            }
            fail(
                not signed(kind, body),
                "Remote image signature is invalid",
                415,
                "invalid_signature",
            );
            return {"body": body, "contentType": kind};
        }
    } finally {
        globalThis.clearTimeout(timeout);
    }
}
