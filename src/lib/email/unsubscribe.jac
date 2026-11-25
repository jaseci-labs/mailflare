glob:priv MAX_HEADER_BYTES: int = 64 * 1024,
          ALLOWED_PROTOCOLS: list[str] = ["http:", "https:", "mailto:"],
          HEADER_END: any = rx(r"\r?\n\r?\n"),
          LINE_BREAK: any = rx(r"\r?\n"),
          FOLDED: any = rx(r"^[\t ]"),
          ANGLES: any = rx(r"^<|>$", "g"),
          QUOTES: any = rx(r'^"|"$', "g"),
          BRACKETED: any = rx(r"<([^>]+)>", "g"),
          ONE_CLICK: any = rx(r"list-unsubscribe\s*=\s*one-click", "i"),
          DKIM_SIGNED: any = rx(r"(?:^|;)\s*h\s*=\s*([^;]+)", "i"),
          UNSUBSCRIBE_WORD: any = rx("unsubscribe", "i"),
          # Bounded quantifiers keep a run of unclosed <a tags linear instead of quadratic.
          ANCHOR: any = rx(
              r"""<a\b[^>]{0,300}?href\s*=\s*["']([^"']{1,1024})["'][^>]{0,300}>([\s\S]{0,600}?)<\/a\s*>""",
              "gi",
          ),
          TEXT_URL: any = rx(r"""https?:\/\/[^\s<>"']+""", "g"),
          TAG: any = rx(r"<[^>]*>", "g"),
          AMPERSAND: any = rx("&amp;", "g"),
          TRAILING_PUNCTUATION: any = rx(r"[.,;:!?)\]}]+$"),
          CONTROL: any = rx(r"[\u0000-\u001f\u007f]", "g"),
          SPACES: any = rx(r"\s+", "g");

def:priv header_block(raw: any) -> str {
    head = raw.slice(0, globalThis.Math.min(raw.byteLength, MAX_HEADER_BYTES));
    text: any = new(globalThis.TextDecoder, "utf-8", record({"fatal": False})).decode(head);
    end = text.search(HEADER_END);
    return text if end == -1 else text.slice(0, end);
}

"""The values of a header in a map of lower-cased names (a JavaScript Map is a Jac dict); none is an empty list."""
def:priv values_of(headers: any, name: str) -> any {
    return either(headers.get(name), []);
}

def:priv parse_headers(block: str) -> any {
    headers: dict[str, any] = {};
    current: any = None;
    for line in globalThis.String.prototype.split.call(block, LINE_BREAK) {
        if FOLDED.test(line) and current {
            values = values_of(headers, current);
            if len(values) {
                values[len(values) - 1] += " " + line.trim();
            }
            continue;
        }
        separator = line.indexOf(":");
        if separator <= 0 {
            current = None;
            continue;
        }
        current = line.slice(0, separator).trim().toLowerCase();
        headers[current] = values_of(headers, current) + [line.slice(separator + 1).trim()];
    }
    return headers;
}

def:priv bare(value: any) -> str {
    return rx_sub(rx_sub(value.trim(), ANGLES, ""), QUOTES, "");
}

def:priv protocol_of(value: str) -> str {
    try {
        return new(globalThis.URL, value).protocol;
    } except Exception {
        return "";
    }
}

def:priv is_http_url(value: str) -> bool {
    return protocol_of(value) in ["http:", "https:"];
}

def:priv candidates_of(value: any) -> list[str] {
    bracketed = [bare(found[1]) for found in globalThis.Array.from(value.matchAll(BRACKETED))];
    return [c for c in bracketed + [bare(part) for part in value.split(",")] if c];
}

"""Every header name covered by any `DKIM-Signature` `h=` list, lower-cased.

RFC 8058 expects the List-Unsubscribe headers to be signed; when none of the message's
signatures covers them, the one-click header could have been added by a relay and is safer
treated as an ordinary link. A forged signature can still claim coverage, so this stays a
best-effort gate, not a verification.
"""
def dkimCoveredHeaders(headers: any) -> any {
    covered = new(globalThis.Set);
    for value in values_of(headers, "dkim-signature") {
        found = DKIM_SIGNED.exec(value);
        if found {
            for name in found[1].split(":") {
                label: any = name;
                covered.add(label.trim().toLowerCase());
            }
        }
    }
    return covered;
}

def:priv first_with(candidates: list[str], prefixes: list[str]) -> any {
    for candidate in candidates {
        for prefix in prefixes {
            if candidate.startswith(prefix) {
                return candidate;
            }
        }
    }
    return NULL;
}

def extractUnsubscribeUrlFromRaw(raw: any) -> any {
    headers = parse_headers(header_block(raw));
    candidates = [
        c
        for value in values_of(headers, "list-unsubscribe")
        for c in candidates_of(value)
        if protocol_of(c) in ALLOWED_PROTOCOLS
    ];
    mailto = first_with(candidates, ["mailto:"]);
    url = either(first_with(candidates, ["https://", "http://"]), mailto);
    if not url {
        return NULL;
    }
    # RFC 8058 marks a one-click endpoint with `List-Unsubscribe-Post: List-Unsubscribe=One-Click`.
    one_click = bool([v for v in values_of(headers, "list-unsubscribe-post") if ONE_CLICK.test(v)]);
    return {
        "url": url,
        "oneClick": one_click,
        "mailto": mailto,
        "dkimCoversUnsubscribe": dkimCoveredHeaders(headers).has("list-unsubscribe"),
    };
}

async def getUnsubscribeUrlFromRawR2Key(env: any, rawR2Key: any) -> any {
    if not rawR2Key {
        return NULL;
    }
    raw = await env.BUCKET.get(
        rawR2Key, record({"range": record({"offset": 0, "length": MAX_HEADER_BYTES})})
    );
    if not raw {
        return NULL;
    }
    return extractUnsubscribeUrlFromRaw(await raw.arrayBuffer());
}

"""The fallback when no List-Unsubscribe header exists.

An anchor whose href or label literally says "unsubscribe", or a bare text URL containing the
word. Only real http(s) links qualify, never a loose string match on body text.
"""
def extractUnsubscribeLinkFromBody(htmlBody: any, textBody: any) -> any {
    if htmlBody {
        for found in globalThis.Array.from(htmlBody.matchAll(ANCHOR)) {
            decoded: any = rx_sub(found[1], AMPERSAND, "&");
            href = decoded.trim();
            if not href or not is_http_url(href) {
                continue;
            }
            label = rx_sub(either(found[2], ""), TAG, " ");
            if UNSUBSCRIBE_WORD.test(href) or UNSUBSCRIBE_WORD.test(label) {
                return href;
            }
        }
    }
    if textBody {
        for found in globalThis.Array.from(textBody.matchAll(TEXT_URL)) {
            url = rx_sub(found[0], TRAILING_PUNCTUATION, "");
            if UNSUBSCRIBE_WORD.test(url) and is_http_url(url) {
                return url;
            }
        }
    }
    return NULL;
}

"""A mailto body/subject must never smuggle extra headers into the composed message."""
def:priv header_safe(value: str, limit: int) -> str {
    flat: any = rx_sub(rx_sub(value, CONTROL, " "), SPACES, " ");
    return flat.trim().slice(0, limit);
}

"""Pulls the recipient out of a `mailto:` candidate, honouring its subject/body params for automated processors."""
def parseMailtoUnsubscribe(url: str) -> any {
    try {
        parsed = new(globalThis.URL, url);
        if parsed.protocol != "mailto:" {
            return NULL;
        }
        path: str = globalThis.decodeURIComponent(parsed.pathname);
        to = header_safe(path.split(",")[0], 253);
        if not to or "@" not in to {
            return NULL;
        }
        params = parsed.searchParams;
        return {
            "to": to,
            "subject": header_safe(either(params.get("subject"), ""), 200) or "unsubscribe",
            "text": header_safe(either(params.get("body"), ""), 1_000) or "unsubscribe",
        };
    } except Exception {
        return NULL;
    }
}
