glob:priv IPV4: any = rx(r"^\d{1,3}(?:\.\d{1,3}){3}$"),
          WWW: any = rx(r"^www\."),
          # Every quantifier is bounded so a run of unclosed <a tags cannot make the scan quadratic.
          LINKED_URL: any = rx(
              r"<a\b[^>]{0,300}?\bhref=[\x22'](https?:\/\/[^\x22']{1,1024})[\x22'][^>]{0,300}>\s{0,200}(https?:\/\/[^<\s]{1,1024})\s{0,200}<\/a>",
              "gi",
          );

def:priv host(url: str) -> str {
    return rx_sub(new(globalThis.URL, url).hostname.toLowerCase(), WWW, "");
}

def analyzeUrls(message: any, prepared: any) -> list[any] {
    domains: any = prepared["urlDomains"];
    signals: list[any] = [];
    if any([IPV4.test(domain) for domain in domains]) {
        signals.append({
            "id": "ip_address_url",
            "score": 8,
            "reason": "A link uses an IP address instead of a domain",
        });
    }
    if any([domain.includes("xn--") for domain in domains]) {
        signals.append({
            "id": "punycode_url",
            "score": 5,
            "reason": "A link uses an internationalized domain encoding",
        });
    }
    if domains.length > 10 {
        signals.append({
            "id": "many_link_domains",
            "score": min(8, domains.length - 8),
            "reason": "Message links to an unusually large number of domains",
            "metadata": {"count": domains.length},
        });
    }
    html: any = at(message, "html", "");
    for found in globalThis.Array.from(html.slice(0, 250000).matchAll(LINKED_URL)) {
        try {
            if host(found[1]) != host(found[2]) {
                signals.append({
                    "id": "displayed_link_mismatch",
                    "score": 10,
                    "reason": "A link's displayed address differs from its destination",
                });
                break;
            }
        } except Exception {}
    }
    return signals;
}
