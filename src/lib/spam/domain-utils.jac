# Second-level suffixes under which names are registered: `shop.example.co.uk` is `example.co.uk`.
glob:priv SUFFIXES: set[str] = set("""co.uk org.uk ac.uk gov.uk me.uk ltd.uk plc.uk com.au net.au
    org.au edu.au gov.au co.nz org.nz net.nz co.jp ne.jp or.jp ac.jp co.kr or.kr com.br net.br
    org.br com.mx com.ar com.co com.pe co.za org.za com.cn net.cn org.cn com.hk com.tw com.sg com.my
    com.ph co.th co.id co.in net.in org.in co.il org.il com.tr com.ua com.pl co.at or.at
    gv.at""".split());

# Registrable domains that are one provider's mailboxes for the general public.
glob:priv SHARED: set[str] = set("""gmail.com googlemail.com outlook.com live.com msn.com icloud.com
    me.com mac.com aol.com proton.me protonmail.com mail.ru zoho.com fastmail.com""".split());

# Providers that run one service under many country domains (yahoo.fr, hotmail.co.uk, gmx.de).
glob:priv SHARED_LABELS: set[str] = set("yahoo hotmail gmx yandex".split());

glob:priv FOLDS: any = [p.split("=") for p in "rn=m vv=w cl=d 0=o [1i|]=l 5=s 3=e -=".split()];

def:priv rootless(host: any) -> str {
    return rx_sub(host.toLowerCase(), rx(r"\.$"), "");
}

"""The domain a name is registered under (approximate public-suffix handling, no list)."""
def registrableDomain(host: str) -> str {
    labels = [label for label in rootless(host).split(".") if label];
    last_two = ".".join(labels[-2:]);
    return ".".join(labels[-3:]) if len(labels) > 2 and last_two in SUFFIXES else last_two;
}

"""True for a name that is itself a registry suffix such as `co.uk`, which no one owns."""
def isMultiPartSuffix(host: str) -> bool {
    return rootless(host) in SUFFIXES;
}

"""The label that identifies the owner, e.g. `paypal` for `mail.paypal.co.uk`."""
def domainOwnerLabel(host: str) -> str {
    return registrableDomain(host).split(".")[0];
}

"""True when anyone can hold an address on the domain, so it says nothing about who a sender is."""
def isSharedMailDomain(host: str) -> bool {
    return registrableDomain(host) in SHARED or domainOwnerLabel(host) in SHARED_LABELS;
}

def isPublicIpv4(value: str) -> bool {
    parts = [globalThis.Number(part) for part in value.split(".")];
    if len(parts) != 4 or not all([whole(part, 0, 255) for part in parts]) {
        return False;
    }
    (a, b) = (parts[0], parts[1]);
    bad = a in [10, 127, 0] or a >= 224 or (a == 172 and 16 <= b <= 31) or (a == 192 and b == 168);
    return not (bad or (a == 169 and b == 254) or (a == 100 and 64 <= b <= 127));
}

"""The IP of the server that handed the message to our MX, from the topmost Received header."""
def extractSenderIp(headers: any = None) -> any {
    # Only the receiving server writes that header, so a sender cannot forge it.
    d = rx(r";\s*(?:mon|tue|wed|thu|fri|sat|sun),", "i");
    top: any = globalThis.String.prototype.split.call(
        findHeader(headers, "received") or "", d
    )[0];
    found = top.matchAll(rx(r"\[(?:IPv6:)?(\d{1,3}(?:\.\d{1,3}){3})\]", "gi"));
    ips = [m[1] for m in globalThis.Array.from(found) if isPublicIpv4(m[1])];
    return ips[0] if ips else NULL;
}

"""Folds characters that look alike so `paypa1` and `rnicrosoft` compare equal to the real names."""
def foldHomoglyphs(label: any) -> str {
    value: str = label.toLowerCase();
    for (pattern, to) in FOLDS {
        value = rx_sub(value, rx(pattern, "g"), to);
    }
    return value;
}

"""Edit distance counting a swap of two neighbouring characters as one edit."""
def editDistance(a: any, b: any) -> int {
    x = [a.charCodeAt(i) for i in range(a.length)];
    y = [b.charCodeAt(i) for i in range(b.length)];
    (w, h) = (len(y) + 1, len(x) + 1);
    d = [[j if i == 0 else i if j == 0 else 0 for j in range(w)] for i in range(h)];
    for i in range(1, h) {
        for j in range(1, w) {
            cost = 0 if x[i - 1] == y[j - 1] else 1;
            d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost);
            if i > 1 and j > 1 and x[i - 1] == y[j - 2] and x[i - 2] == y[j - 1] {
                d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1);
            }
        }
    }
    return d[len(x)][len(y)];
}

"""True when `candidate` is not `known` but looks close enough to be mistaken for it."""
def isLookalikeDomain(candidate: str, known: str) -> bool {
    (a, b) = (registrableDomain(candidate), registrableDomain(known));
    (la, lb) = (a.split(".")[0], b.split(".")[0]);
    n: int = globalThis.String(lb).length;
    # The same name under another suffix (example.ch / example.com) is usually the same owner.
    if not a or not b or a == b or n < 5 or la == lb {
        return False;
    }
    return foldHomoglyphs(la) == foldHomoglyphs(lb) or editDistance(la, lb) <= 1 + int(n >= 9);
}
