type DnsQueryType = str;

glob:priv DOH_ENDPOINT: str = "https://cloudflare-dns.com/dns-query",
          DOH_TIMEOUT_MS: int = 5000,
          DNS_RECORD_TYPES: dict[str, int] = {
              "A": 1,
              "AAAA": 28,
              "CNAME": 5,
              "MX": 15,
              "PTR": 12,
              "TXT": 16,
          },
          IPV4: any = rx(
              r"^(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$"
          ),
          IPV4_TAIL: any = rx(r"(?:^|:)(\d+\.\d+\.\d+\.\d+)$"),
          HEX_GROUP: any = rx(r"^[0-9a-f]{1,4}$", "i"),
          TXT_CHUNK: any = rx(r'"([^"]*)"', "g");

def:priv hex(n: any) -> any {
    return globalThis.Number(n).toString(16);
}

"""The eight 16-bit groups of an IPv6 literal (`::` and a trailing IPv4 allowed), or None."""
def:priv ipv6_groups(ip: any) -> any {
    text = ip;
    tail = IPV4_TAIL.exec(text);
    if tail {
        if not IPV4.test(tail[1]) {
            return None;
        }
        (a, b, c, d) = [globalThis.Number(part) for part in tail[1].split(".")];
        text = f"{text.slice(0, -tail[1].length)}{hex(a * 256 + b)}:{hex(c * 256 + d)}";
    }
    halves = text.split("::");
    if len(halves) > 2 {
        return None;
    }
    elided = len(halves) == 2;
    head = halves[0].split(":") if halves[0] else [];
    rest = halves[1].split(":") if elided and halves[1] else [];
    missing = 8 - len(head) - len(rest);
    if (missing < 1) if elided else (missing != 0) {
        return None;
    }
    groups = [*head, *(["0"] * missing), *rest];
    if len(groups) != 8 or [g for g in groups if not HEX_GROUP.test(g)] {
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
    if not groups {
        return NULL;
    }
    nibbles: str = "".join([hex(g).padStart(4, "0") for g in groups]);
    return ".".join(nibbles[::-1]) + ".ip6.arpa";
}

def:priv decode_txt(data: any) -> str {
    chunks = data.match(TXT_CHUNK);
    return "".join([chunk.slice(1, -1) for chunk in chunks]) if chunks else data.trim();
}

"""
Resolves a name over DNS-over-HTTPS so the same code path works on Workers (no Node `dns` module)
and in the self-hosted runtime. `NXDOMAIN` and an empty `NOERROR` answer both map to an empty
list; any other failure throws so callers can tell "missing" apart from "could not check".
"""
async def queryDns(name: any, kind: any) -> list[any] {
    controller = new(globalThis.AbortController);
    def abort {
        controller.abort();
    }
    timeout = globalThis.setTimeout(abort, DOH_TIMEOUT_MS);
    try {
        response = await globalThis.fetch(
            f"{DOH_ENDPOINT}?name={globalThis.encodeURIComponent(name)}&type={kind}",
            record({
                "headers": record({"accept": "application/dns-json"}),
                "signal": controller.signal,
            }),
        );
        if not response.ok {
            raise new(globalThis.Error, f"DNS query for {name} {kind} failed ({response.status})");
        }
        json = await response.json();
        if json.Status not in [0, 3] {
            raise new(
                globalThis.Error, f"DNS query for {name} {kind} returned status {json.Status}"
            );
        }
        # An A/AAAA lookup answers with a first CNAME record alongside the requested type, so keep
        # only records that match what was asked for. Reporting CNAME names where IPs are expected
        # makes callers treat host names as addresses and reject them.
        return [
            decode_txt(answer.data) if kind == "TXT" else answer.data
            for answer in at(json, "Answer", [])
            if answer["type"] == DNS_RECORD_TYPES.get(kind)
        ];
    } finally {
        globalThis.clearTimeout(timeout);
    }
}
