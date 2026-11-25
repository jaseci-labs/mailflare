# Spam scoring calls these on every inbound mail, so they work on whole strings with JavaScript's own
# methods (UTF-16, as the original) instead of character loops and Jac's code-point string helpers.

# Second-level suffixes under which names are registered: `shop.example.co.uk` is `example.co.uk`.
glob:priv SUFFIXES: set[str] = set("""co.uk org.uk ac.uk gov.uk me.uk ltd.uk plc.uk com.au net.au
    org.au edu.au gov.au co.nz org.nz net.nz co.jp ne.jp or.jp ac.jp co.kr or.kr com.br net.br
    org.br com.mx com.ar com.co com.pe co.za org.za com.cn net.cn org.cn com.hk com.tw com.sg com.my
    com.ph co.th co.id co.in net.in org.in co.il org.il com.tr com.ua com.pl co.at or.at
    gv.at""".split()),
          # Registrable domains that are one provider's mailboxes for the general public.
          SHARED: set[str] = set("""gmail.com googlemail.com outlook.com live.com msn.com icloud.com
    me.com mac.com aol.com proton.me protonmail.com mail.ru zoho.com fastmail.com""".split()),
          # Providers that run one service under many country domains (yahoo.fr, hotmail.co.uk, gmx.de).
          SHARED_LABELS: set[str] = set("yahoo hotmail gmx yandex".split()),
          TRAILING_DOT: any = rx(r"\.$"),
          # A name whose labels are not simply its dot-separated pieces: an empty label to drop.
          EMPTY_LABEL: any = rx(r"^\.|\.\.|\.$"),
          DOT_RUNS: any = rx(r"\.+", "g"),
          EDGE_DOTS: any = rx(r"^\.|\.$", "g"),
          RECEIVED_DATE: any = rx(r";\s*(?:mon|tue|wed|thu|fri|sat|sun),", "i"),
          BRACKETED_IPV4: any = rx(r"\[(?:IPv6:)?(\d{1,3}(?:\.\d{1,3}){3})\]", "gi"),
          # Homoglyph folds, applied in this order (a `g` regex's lastIndex is reset by replace).
          FOLD_RN: any = rx("rn", "g"),
          FOLD_VV: any = rx("vv", "g"),
          FOLD_CL: any = rx("cl", "g"),
          FOLD_0: any = rx("0", "g"),
          FOLD_1: any = rx("[1i|]", "g"),
          FOLD_5: any = rx("5", "g"),
          FOLD_3: any = rx("3", "g"),
          FOLD_DASH: any = rx("-", "g");

def:priv lower(s: any) -> str {
    return globalThis.String.prototype.toLowerCase.call(s);
}

def:priv rootless(host: any) -> str {
    return globalThis.String.prototype.replace.call(lower(host), TRAILING_DOT, "");
}

# The first label of a registrable domain (`a.split(".")[0]`).
def:priv first_label(domain: any) -> str {
    dot: int = globalThis.String.prototype.indexOf.call(domain, ".");
    return domain if dot < 0 else globalThis.String.prototype.slice.call(domain, 0, dot);
}

"""The domain a name is registered under (approximate public-suffix handling, no list)."""
def registrableDomain(host: str) -> str {
    # The non-empty labels joined by dots: the name with dot runs collapsed and edge dots dropped.
    name: any = lower(host);
    if globalThis.RegExp.prototype.test.call(EMPTY_LABEL, name) {
        name = globalThis.String.prototype.replace.call(
            globalThis.String.prototype.replace.call(name, DOT_RUNS, "."), EDGE_DOTS, ""
        );
    }
    last: int = globalThis.String.prototype.lastIndexOf.call(name, ".");
    if last < 0 {
        return name;
    }
    second: int = globalThis.String.prototype.lastIndexOf.call(name, ".", last - 1);
    if second < 0 {
        return name;
    }
    last_two: str = globalThis.String.prototype.slice.call(name, second + 1);
    if last_two not in SUFFIXES {
        return last_two;
    }
    third: int = globalThis.String.prototype.lastIndexOf.call(name, ".", second - 1);
    return globalThis.String.prototype.slice.call(name, third + 1);
}

"""True for a name that is itself a registry suffix such as `co.uk`, which no one owns."""
def isMultiPartSuffix(host: str) -> bool {
    return rootless(host) in SUFFIXES;
}

"""The label that identifies the owner, e.g. `paypal` for `mail.paypal.co.uk`."""
def domainOwnerLabel(host: str) -> str {
    return first_label(registrableDomain(host));
}

"""True when anyone can hold an address on the domain, so it says nothing about who a sender is."""
def isSharedMailDomain(host: str) -> bool {
    domain = registrableDomain(host);
    return domain in SHARED or first_label(domain) in SHARED_LABELS;
}

def isPublicIpv4(value: str) -> bool {
    parts: any = globalThis.String.prototype.split.call(value, ".");
    if parts.length != 4 {
        return False;
    }
    for part in parts {
        if not whole(globalThis.Number(part), 0, 255) {
            return False;
        }
    }
    a: int = globalThis.Number(parts[0]);
    b: int = globalThis.Number(parts[1]);
    bad = a == 10 or a == 127 or a == 0 or a >= 224 or (a == 172 and 16 <= b <= 31);
    bad = bad or (a == 192 and b == 168);
    return not (bad or (a == 169 and b == 254) or (a == 100 and 64 <= b <= 127));
}

"""The IP of the server that handed the message to our MX, from the topmost Received header."""
def extractSenderIp(headers: any = None) -> any {
    # Only the receiving server writes that header, so a sender cannot forge it.
    received: any = findHeader(headers, "received");
    if not received {
        return NULL;
    }
    top: any = globalThis.String.prototype.split.call(received, RECEIVED_DATE)[0];
    found = globalThis.String.prototype.matchAll.call(top, BRACKETED_IPV4);
    for m in globalThis.Array.from(found) {
        if isPublicIpv4(m[1]) {
            return m[1];
        }
    }
    return NULL;
}

"""Folds characters that look alike so `paypa1` and `rnicrosoft` compare equal to the real names."""
def foldHomoglyphs(label: any) -> str {
    value: any = lower(label);
    value = globalThis.String.prototype.replace.call(value, FOLD_RN, "m");
    value = globalThis.String.prototype.replace.call(value, FOLD_VV, "w");
    value = globalThis.String.prototype.replace.call(value, FOLD_CL, "d");
    value = globalThis.String.prototype.replace.call(value, FOLD_0, "o");
    value = globalThis.String.prototype.replace.call(value, FOLD_1, "l");
    value = globalThis.String.prototype.replace.call(value, FOLD_5, "s");
    value = globalThis.String.prototype.replace.call(value, FOLD_3, "e");
    return globalThis.String.prototype.replace.call(value, FOLD_DASH, "");
}

"""Edit distance counting a swap of two neighbouring characters as one edit."""
def editDistance(a: any, b: any) -> int {
    # UTF-16 code units, as JavaScript's `a[i]` compares them.
    a_length: int = globalThis.String(a).length;
    b_length: int = globalThis.String(b).length;
    h = a_length + 1;
    w = b_length + 1;
    y: list[int] = [];
    for j in range(w - 1) {
        y.append(globalThis.String.prototype.charCodeAt.call(b, j));
    }
    # Three rows of the table (i - 2, i - 1, i); the cells to the left and up-left of the one
    # being filled are carried in variables, so each cell reads one value from the rows.
    before: list[int] = [];
    above: list[int] = [];
    for j in range(w) {
        above.append(j);
    }
    x_before = -1;
    for i in range(1, h) {
        xi: int = globalThis.String.prototype.charCodeAt.call(a, i - 1);
        row: list[int] = [i];
        left = i;
        diagonal = i - 1;
        y_before = -1;
        for j in range(1, w) {
            up = above[j];
            yj = y[j - 1];
            best = up + 1;
            if left + 1 < best {
                best = left + 1;
            }
            if diagonal + int(xi != yj) < best {
                best = diagonal + int(xi != yj);
            }
            if i > 1 and j > 1 and xi == y_before and x_before == yj and before[j - 2] + 1 < best {
                best = before[j - 2] + 1;
            }
            row.append(best);
            left = best;
            diagonal = up;
            y_before = yj;
        }
        before = above;
        above = row;
        x_before = xi;
    }
    return above[w - 1];
}

"""True when `candidate` is not `known` but looks close enough to be mistaken for it."""
def isLookalikeDomain(candidate: str, known: str) -> bool {
    a = registrableDomain(candidate);
    b = registrableDomain(known);
    if not a or not b or a == b {
        return False;
    }
    la = first_label(a);
    lb = first_label(b);
    n: int = globalThis.String(lb).length;
    # The same name under another suffix (example.ch / example.com) is usually the same owner.
    if n < 5 or la == lb {
        return False;
    }
    return foldHomoglyphs(la) == foldHomoglyphs(lb) or editDistance(la, lb) <= 1 + int(n >= 9);
}
