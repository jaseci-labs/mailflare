"""Second-level suffixes under which names are registered, so `shop.example.co.uk` reduces to `example.co.uk`."""
glob:priv MULTI_PART_SUFFIXES: set[str] = {
              "co.uk",
              "org.uk",
              "ac.uk",
              "gov.uk",
              "me.uk",
              "ltd.uk",
              "plc.uk",
              "com.au",
              "net.au",
              "org.au",
              "edu.au",
              "gov.au",
              "co.nz",
              "org.nz",
              "net.nz",
              "co.jp",
              "ne.jp",
              "or.jp",
              "ac.jp",
              "co.kr",
              "or.kr",
              "com.br",
              "net.br",
              "org.br",
              "com.mx",
              "com.ar",
              "com.co",
              "com.pe",
              "co.za",
              "org.za",
              "com.cn",
              "net.cn",
              "org.cn",
              "com.hk",
              "com.tw",
              "com.sg",
              "com.my",
              "com.ph",
              "co.th",
              "co.id",
              "co.in",
              "net.in",
              "org.in",
              "co.il",
              "org.il",
              "com.tr",
              "com.ua",
              "com.pl",
              "co.at",
              "or.at",
              "gv.at",
          },
          # Registrable domains that are one provider's mailboxes for the general public.
          SHARED_MAIL_DOMAINS: set[str] = {
              "gmail.com",
              "googlemail.com",
              "outlook.com",
              "live.com",
              "msn.com",
              "icloud.com",
              "me.com",
              "mac.com",
              "aol.com",
              "proton.me",
              "protonmail.com",
              "mail.ru",
              "zoho.com",
              "fastmail.com",
          },
          # Providers that run the same service under many country domains (yahoo.fr, hotmail.co.uk, gmx.de, yandex.ru).
          SHARED_MAIL_LABELS: set[str] = {"yahoo", "hotmail", "gmx", "yandex"},
          ROOT_DOT: any = rx(r"\.$"),
          RECEIVED_DATE: any = rx(r";\s*(?:mon|tue|wed|thu|fri|sat|sun),", "i"),
          BRACKETED_IP: any = rx(r"\[(?:IPv6:)?(\d{1,3}(?:\.\d{1,3}){3})\]", "gi"),
          HOMOGLYPHS: list[tuple[any, str]] = [
              (rx("rn", "g"), "m"),
              (rx("vv", "g"), "w"),
              (rx("cl", "g"), "d"),
              (rx("0", "g"), "o"),
              (rx("[1i|]", "g"), "l"),
              (rx("5", "g"), "s"),
              (rx("3", "g"), "e"),
              (rx("-", "g"), ""),
          ];

def:priv rootless(host: any) -> str {
    return rx_sub(host.toLowerCase(), ROOT_DOT, "");
}

"""The domain a name is registered under (approximate public-suffix handling, no list dependency)."""
def registrableDomain(host: str) -> str {
    labels = [label for label in rootless(host).split(".") if label];
    if len(labels) <= 2 {
        return ".".join(labels);
    }
    last_two = ".".join(labels[-2:]);
    return ".".join(labels[-3:]) if last_two in MULTI_PART_SUFFIXES else last_two;
}

"""True for a name that is itself a registry suffix such as `co.uk`, which no one owns."""
def isMultiPartSuffix(host: str) -> bool {
    return rootless(host) in MULTI_PART_SUFFIXES;
}

"""The label that identifies the owner, e.g. `paypal` for `mail.paypal.co.uk`."""
def domainOwnerLabel(host: str) -> str {
    return registrableDomain(host).split(".")[0];
}

"""True when anyone can hold an address on the domain, so it says nothing about who a sender is."""
def isSharedMailDomain(host: str) -> bool {
    return registrableDomain(host) in SHARED_MAIL_DOMAINS
        or domainOwnerLabel(host) in SHARED_MAIL_LABELS;
}

def isPublicIpv4(value: str) -> bool {
    parts = [globalThis.Number(part) for part in value.split(".")];
    if len(parts) != 4
        or any([not globalThis.Number.isInteger(part) or part < 0 or part > 255 for part in parts])
    {
        return False;
    }
    (a, b) = (parts[0], parts[1]);
    return not (
        a in [10, 127, 0]
        or a >= 224
        or (a == 172 and 16 <= b <= 31)
        or (a == 192 and b == 168)
        or (a == 169 and b == 254)
        or (a == 100 and 64 <= b <= 127)
    );
}

"""
The IP of the server that handed the message to our MX, from the topmost Received header. Only the
receiving server writes that header, so a sender cannot forge it; at worst a missing one means no lookup.
"""
def extractSenderIp(headers: any = None) -> any {
    received = findHeader(headers, "received");
    if not received {
        return NULL;
    }
    first: any = globalThis.String.prototype.split.call(received, RECEIVED_DATE)[0];
    for found in globalThis.Array.from(first.matchAll(BRACKETED_IP)) {
        if isPublicIpv4(found[1]) {
            return found[1];
        }
    }
    return NULL;
}

"""Folds characters that look alike so `paypa1` and `rnicrosoft` compare equal to the real names."""
def foldHomoglyphs(label: any) -> str {
    value: str = label.toLowerCase();
    for (pattern, replacement) in HOMOGLYPHS {
        value = rx_sub(value, pattern, replacement);
    }
    return value;
}

"""Edit distance counting a swap of two neighbouring characters as one edit."""
def editDistance(a: any, b: any) -> int {
    (rows, cols) = (a.length + 1, b.length + 1);
    d = [[(j if i == 0 else i if j == 0 else 0) for j in range(cols)] for i in range(rows)];
    for i in range(1, rows) {
        for j in range(1, cols) {
            cost = 0 if a.charCodeAt(i - 1) == b.charCodeAt(j - 1) else 1;
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost);
            if i > 1
                and j > 1
                and a.charCodeAt(i - 1) == b.charCodeAt(j - 2)
                and a.charCodeAt(i - 2) == b.charCodeAt(j - 1)
            {
                d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1);
            }
        }
    }
    return d[rows - 1][cols - 1];
}

"""True when `candidate` is not `known` but looks close enough to be mistaken for it."""
def isLookalikeDomain(candidate: str, known: str) -> bool {
    (a, b) = (registrableDomain(candidate), registrableDomain(known));
    if not a or not b or a == b {
        return False;
    }
    (label_a, label_b) = (a.split(".")[0], b.split(".")[0]);
    # The same name under another suffix (example.ch / example.com) is usually the same owner.
    if len(label_b) < 5 or label_a == label_b {
        return False;
    }
    if foldHomoglyphs(label_a) == foldHomoglyphs(label_b) {
        return True;
    }
    return editDistance(label_a, label_b) <= (2 if len(label_b) >= 9 else 1);
}
