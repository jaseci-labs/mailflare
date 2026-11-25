"""Transparent 1x1 GIF."""
glob TRACKING_PIXEL_GIF: any = globalThis.Uint8Array.from(
         globalThis.atob("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"),
         lambda (char: any) -> any { char.charCodeAt(0) }
     ),
     TRACKING_PIXEL_HEADERS: any = record({
         "Content-Type": "image/gif",
         "Cache-Control": "no-store, no-cache, must-revalidate, private, max-age=0",
         "Pragma": "no-cache",
         "Expires": "0",
         "Referrer-Policy": "no-referrer",
         "X-Content-Type-Options": "nosniff"
     }),
     # Scanners and Apple's prefetch fetch images within seconds of delivery; a person rarely does.
     AUTOMATED_OPEN_WINDOW_MS: int = 10000,
     # Repeat fetches by the same client inside this window count as one open.
     DUPLICATE_OPEN_WINDOW_MS: int = 30000,
     # Opens beyond this per message still update the counters but are not stored individually.
     MAX_STORED_OPENS: int = 50;

glob:priv TOKEN_PATTERN: any = rx(r"^[A-Za-z0-9_-]{20,64}$"),
          # Apple Inc. networks; Mail Privacy Protection fetches every image through them on delivery.
          APPLE_ASNS: list[int] = [714, 6185],
          HOSTNAME_LABEL: any = rx(r"^(?!-)[a-z0-9-]{1,63}(?<!-)$"),
          BODY_CLOSE: any = rx(r"<\/body\s*>", "i"),
          COUNTRY: any = rx(r"^[A-Z]{2}$"),
          DEVICES: list[tuple[str, str]] = [
              ("iPhone", "iPhone"),
              ("iPad", "iPad"),
              ("Android", "Android"),
              ("Macintosh|Mac OS X", "Mac"),
              ("Windows", "Windows"),
              ("CrOS", "ChromeOS"),
              ("Linux", "Linux")
          ],
          CLIENTS: list[tuple[str, str, bool]] = [
              (r"GoogleImageProxy|ggpht\.com", "Gmail", True),
              ("YahooMailProxy", "Yahoo Mail", True),
              ("Mailflare-Remote-Images", "Mailflare", True),
              (
                  "Outlook-iOS|Outlook-Android|Microsoft Outlook|MSOffice|ms-office|Microsoft Office",
                  "Outlook",
                  False
              ),
              ("Thunderbird", "Thunderbird", False)
          ];

def:priv seen(pattern: str, text: str) -> bool {
    return rx(pattern, "i").test(text);
}

def:priv trimmed(text: any) -> any {
    return text.trim() if text else text;
}

def createTrackingToken -> str {
    chars: str = globalThis.String.fromCharCode.apply(
        NULL,
        globalThis.crypto.getRandomValues(new(globalThis.Uint8Array, 18))
    );
    return globalThis.btoa(chars).replace("+", "-").replace("/", "_").rstrip("=");
}

"""Accepts `<token>` or `<token>.gif` from the pixel URL."""
def parseTrackingToken(segment: str) -> any {
    token = segment.removesuffix(".gif");
    return token if TOKEN_PATTERN.test(token) else NULL;
}

def buildTrackingPixelUrl(origin: str, token: str) -> str {
    return f"{origin.rstrip('/')}/api/i/{token}.gif";
}

"""Picks the public origin for pixel URLs, or null when only a non-HTTP origin is known."""
def resolveTrackingOrigin(appUrl: any = None, publicOrigin: any = None) -> any {
    for candidate in [trimmed(appUrl), trimmed(publicOrigin)] {
        if not candidate {
            continue;
        }
        try {
            url = new(globalThis.URL, candidate);
            if url.protocol in ["https:", "http:"] {
                return url.origin;
            }
        } except Exception {
            # Try the next candidate.
        }
    }
    return NULL;
}

"""
Normalises a domain's pixel hostname. It must be the domain itself or one of its subdomains,
so the pixel never names a host the sender does not own.
"""
def normalizeTrackingHost(given: any, domainHostname: any) -> dict[str, any] {
    hostname: str = given.trim().toLowerCase();
    for pattern in [r"^https?:\/\/", r"\/.*$", r"\.$"] {
        hostname = rx_sub(hostname, rx(pattern), "");
    }
    domain: str = domainHostname.trim().toLowerCase();
    if not hostname
    or len(hostname) > 253
    or not all([HOSTNAME_LABEL.test(label) for label in hostname.split(".")]) {
        return {"error": "invalid"};
    }
    if hostname != domain and not hostname.endswith(f".{domain}") {
        return {"error": "outsideDomain"};
    }
    return {"hostname": hostname};
}

"""Appends the pixel inside `<body>` when there is one, otherwise at the end."""
def injectTrackingPixel(html: any, pixelUrl: str) -> str {
    escaped = pixelUrl.replace("&", "&amp;").replace('"', "&quot;");
    img = f'<img src="{escaped}" width="1" height="1" alt="" style="display:block;width:1px;height:1px;border:0;margin:0;padding:0;opacity:0" />';
    close: int = html.search(BODY_CLOSE);
    return f"{html}{img}" if close == -1 else f"{html.slice(0, close)}{img}{html.slice(close)}";
}

def:priv detect_device(agent: str) -> any {
    for (pattern, device) in DEVICES {
        if seen(pattern, agent) {
            return device;
        }
    }
    return NULL;
}

def:priv detect_client(agent: str) -> tuple[any, bool] {
    for (pattern, client, proxied) in CLIENTS {
        if seen(pattern, agent) {
            return (client, proxied);
        }
    }
    if seen("AppleWebKit", agent)
    and not seen(r"Chrome|CriOS|Safari\/", agent)
    and seen("iPhone|iPad|Macintosh", agent) {
        return ("Apple Mail", False);
    }
    return (NULL, False);
}

"""
Names the client behind a pixel fetch and flags fetches no person caused.
Proxied fetches (Gmail, Yahoo, Apple) reveal neither device nor location.
"""
def classifyOpen(info: any) -> dict[str, any] {
    agent: any = at(info, "userAgent", "");
    if at(info, "asn") in APPLE_ASNS or agent.trim() == "Mozilla/5.0" {
        return {"client": "Apple Mail", "device": NULL, "country": NULL, "city": NULL, "automated": True};
    }
    (client, proxied) = detect_client(agent);
    # Cloudflare reports XX for unknown and T1 for Tor.
    country = at(info, "country");
    located = country and COUNTRY.test(country) and country not in ["XX", "T1"];
    return {
        "client": client,
        "device": NULL if proxied else detect_device(agent),
        "country": country if located and not proxied else NULL,
        "city": NULL if proxied else at(info, "city", NULL),
        "automated": info.openedAt.getTime() - info.sentAt.getTime() < AUTOMATED_OPEN_WINDOW_MS
    };
}

def isDuplicateOpen(previous: any, following: any) -> bool {
    if not previous {
        return False;
    }
    return previous.client is following.client
        and previous.device is following.device
        and following.openedAt.getTime() - previous.openedAt.getTime() < DUPLICATE_OPEN_WINDOW_MS;
}
