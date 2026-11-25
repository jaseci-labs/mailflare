# Rows of a `;`-separated table, each split into fields on `sep`.
def:priv table(text: str, sep: str = "=") -> list[any] {
    return [row.strip().split(sep) for row in text.split(";")];
}

# A transparent 1x1 GIF and the headers it is served with.
glob TRACKING_PIXEL_GIF: any = globalThis.Uint8Array.from(
         globalThis.atob("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"),
         lambda (char: any) -> any { char.charCodeAt(0) },
     ),
     TRACKING_PIXEL_HEADERS: any = record(dict(table("""Content-Type: image/gif;
         Cache-Control: no-store, no-cache, must-revalidate, private, max-age=0; Pragma: no-cache;
         Expires: 0; Referrer-Policy: no-referrer; X-Content-Type-Options: nosniff""", ": "))),
     # Scanners and Apple's prefetch fetch images within seconds of delivery; a person rarely does.
     AUTOMATED_OPEN_WINDOW_MS: int = 10000,
     # Repeat fetches by the same client inside this window count as one open.
     DUPLICATE_OPEN_WINDOW_MS: int = 30000,
     # Opens beyond this per message still update the counters but are not stored individually.
     MAX_STORED_OPENS: int = 50;

# APPLE_ASNS: Apple Inc. networks; Mail Privacy Protection fetches every image through them.
# DEVICES and CLIENTS are `pattern=name` (`=proxied` when a proxy hides device and location).
glob:priv APPLE_ASNS: list[int] = [714, 6185],
          APPLE_PROXY: list[any] = ["Apple Mail", True],
          HOSTNAME_LABEL: any = rx(r"^(?!-)[a-z0-9-]{1,63}(?<!-)$"),
          DEVICES: list[any] = table("""iPhone=iPhone;iPad=iPad;Android=Android;
              Macintosh|Mac OS X=Mac;Windows=Windows;CrOS=ChromeOS;Linux=Linux"""),
          CLIENTS: list[any] = table(r"""GoogleImageProxy|ggpht\.com=Gmail=1;
              YahooMailProxy=Yahoo Mail=1;Mailflare-Remote-Images=Mailflare=1;
        Outlook-iOS|Outlook-Android|Microsoft Outlook|MSOffice|ms-office|Microsoft Office=Outlook=;
              Thunderbird=Thunderbird=""");

def:priv seen(pattern: str, text: str) -> bool {
    return rx(pattern, "i").test(text);
}

def createTrackingToken -> str {
    random = globalThis.crypto.getRandomValues(new(globalThis.Uint8Array, 18));
    chars: str = globalThis.String.fromCharCode.apply(NULL, random);
    return globalThis.btoa(chars).replace("+", "-").replace("/", "_").rstrip("=");
}

# Accepts `<token>` or `<token>.gif` from the pixel URL.
def parseTrackingToken(segment: str) -> any {
    token = segment.removesuffix(".gif");
    return token if rx(r"^[A-Za-z0-9_-]{20,64}$").test(token) else NULL;
}

def buildTrackingPixelUrl(origin: str, token: str) -> str {
    return f"{origin.rstrip('/')}/api/i/{token}.gif";
}

# Picks the public origin for pixel URLs, or null when only a non-HTTP origin is known.
def resolveTrackingOrigin(appUrl: any = None, publicOrigin: any = None) -> any {
    for candidate in [c.trim() for c in [appUrl, publicOrigin] if c and c.trim()] {
        try {
            url = new(globalThis.URL, candidate);
            if url.protocol in ["https:", "http:"] {
                return url.origin;
            }
        } except Exception {}
    }
    return NULL;
}

# A domain's pixel hostname: the domain itself or a subdomain, never a host the sender does not own.
def normalizeTrackingHost(given: any, domainHostname: any) -> dict[str, any] {
    hostname: str = given.trim().toLowerCase();
    for pattern in [r"^https?:\/\/", r"\/.*$", r"\.$"] {
        hostname = rx_sub(hostname, rx(pattern), "");
    }
    domain: str = domainHostname.trim().toLowerCase();
    labels_ok = all(HOSTNAME_LABEL.test(label) for label in hostname.split("."));
    if not hostname or len(hostname) > 253 or not labels_ok {
        return {"error": "invalid"};
    }
    if hostname != domain and not hostname.endswith(f".{domain}") {
        return {"error": "outsideDomain"};
    }
    return {"hostname": hostname};
}

# Appends the pixel inside `<body>` when there is one, otherwise at the end.
def injectTrackingPixel(html: any, pixelUrl: str) -> str {
    escaped = pixelUrl.replace("&", "&amp;").replace('"', "&quot;");
    img = f'<img src="{escaped}" width="1" height="1" alt="" style="display:block;width:1px;height:1px;border:0;margin:0;padding:0;opacity:0" />';
    close: int = html.search(rx(r"<\/body\s*>", "i"));
    return f"{html}{img}" if close == -1 else f"{html.slice(0, close)}{img}{html.slice(close)}";
}

def:priv detect_client(agent: str) -> list[any] {
    for (pattern, client, proxied) in CLIENTS {
        if seen(pattern, agent) {
            return [client, bool(proxied)];
        }
    }
    webkit = seen("AppleWebKit", agent) and not seen(r"Chrome|CriOS|Safari\/", agent);
    return [NULL, False]
        if not webkit or not seen("iPhone|iPad|Macintosh", agent)
        else ["Apple Mail", False];
}

# Names the client behind a pixel fetch and flags fetches no person caused. Proxied fetches
# (Gmail, Yahoo, Apple) reveal neither device nor location.
def classifyOpen(info: any) -> dict[str, any] {
    agent: any = at(info, "userAgent", "");
    apple = at(info, "asn") in APPLE_ASNS or agent.trim() == "Mozilla/5.0";
    (client, proxied) = detect_client(agent) if not apple else APPLE_PROXY;
    # Cloudflare reports XX for unknown and T1 for Tor.
    country = at(info, "country");
    located = country and rx(r"^[A-Z]{2}$").test(country) and country not in ["XX", "T1"];
    return {
        "client": client,
        "device": NULL if proxied else next((d for (p, d) in DEVICES if seen(p, agent)), NULL),
        "country": country if located and not proxied else NULL,
        "city": NULL if proxied else at(info, "city", NULL),
        "automated": apple
            or info.openedAt.getTime() - info.sentAt.getTime() < AUTOMATED_OPEN_WINDOW_MS,
    };
}

def isDuplicateOpen(previous: any, following: any) -> bool {
    return bool(previous)
        and previous.client is following.client
        and previous.device is following.device
        and following.openedAt.getTime() - previous.openedAt.getTime() < DUPLICATE_OPEN_WINDOW_MS;
}
