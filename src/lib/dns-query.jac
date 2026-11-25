type DnsQueryType = str;

glob:priv TYPES: any = record({"A": 1, "AAAA": 28, "CNAME": 5, "MX": 15, "PTR": 12, "TXT": 16}),
          OCTET: str = r"(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)",
          IPV4: any = rx(f"^(?:{OCTET}\\.){{3}}{OCTET}$");

def:priv hex(n: any) -> any {
    return globalThis.Number(n).toString(16);
}

"""The eight 16-bit groups of an IPv6 literal (`::` and a trailing IPv4 allowed), or None."""
def:priv ipv6_groups(text: any) -> any {
    tail = rx(r"(?:^|:)(\d+\.\d+\.\d+\.\d+)$").exec(text);
    if tail and not IPV4.test(tail[1]) {
        return None;
    }
    if tail {
        (a, b, c, d) = [globalThis.Number(part) for part in tail[1].split(".")];
        text = f"{text.slice(0, -tail[1].length)}{hex(a * 256 + b)}:{hex(c * 256 + d)}";
    }
    parse = lambda (p: str) -> list[str] { p.split(":") if p else [] };
    halves = text.split("::");
    (head, rest) = (parse(halves[0]), parse(halves[1]) if len(halves) == 2 else []);
    missing = 8 - len(head) - len(rest);
    groups = [*head, *(["0"] * missing), *rest] if len(halves) == 2 and missing >= 1 else head;
    valid = len(halves) == 2 and missing >= 1 or len(halves) == 1 and missing == 0;
    hexes = all([rx(r"^[0-9a-f]{1,4}$", "i").test(g) for g in groups]);
    if not valid or len(groups) != 8 or not hexes {
        return None;
    }
    return [globalThis.Number.parseInt(g, 16) for g in groups];
}

"""The PTR query name for an IPv4 or IPv6 literal, or null when the text is not an IP address."""
def reverseName(ip: any) -> any {
    if IPV4.test(ip) {
        return ".".join(ip.split(".")[::-1]) + ".in-addr.arpa";
    }
    groups = ipv6_groups(ip) if ":" in ip else None;
    nibbles: str = "".join([hex(g).padStart(4, "0") for g in groups]) if groups else "";
    return ".".join(nibbles[::-1]) + ".ip6.arpa" if groups else NULL;
}

def:priv decode_txt(data: any) -> str {
    chunks = data.match(rx(r'"([^"]*)"', "g"));
    return "".join([chunk.slice(1, -1) for chunk in chunks]) if chunks else data.trim();
}

"""
Resolves a name over DNS-over-HTTPS so the same code path works on Workers (no Node `dns` module)
and in the self-hosted runtime. `NXDOMAIN` and an empty `NOERROR` answer both map to an empty
list; any other failure throws so callers can tell "missing" apart from "could not check".
"""
async def queryDns(name: any, kind: any) -> list[any] {
    controller = new(globalThis.AbortController);
    timeout = globalThis.setTimeout(lambda -> any { controller.abort() }, 5000);
    try {
        query = f"name={globalThis.encodeURIComponent(name)}&type={kind}";
        url = f"https://cloudflare-dns.com/dns-query?{query}";
        init = {"headers": record({"accept": "application/dns-json"}), "signal": controller.signal};
        response = await globalThis.fetch(url, record(init));
        if not response.ok {
            raise new(globalThis.Error, f"DNS query for {name} {kind} failed ({response.status})");
        }
        json = await response.json();
        status = json["Status"];
        if status not in [0, 3] {
            why = f"returned status {globalThis.String(status)}";
            raise new(globalThis.Error, f"DNS query for {name} {kind} {why}");
        }
        # An A/AAAA lookup answers with a first CNAME record alongside the requested type: keep only
        # what was asked for, or callers take host names for addresses and reject them.
        answers = [a for a in at(json, "Answer", []) if a["type"] == at(TYPES, kind)];
        return [decode_txt(a["data"]) if kind == "TXT" else a["data"] for a in answers];
    } finally {
        globalThis.clearTimeout(timeout);
    }
}
