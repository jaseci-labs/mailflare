type DnsAuthRecord = str;

type DnsAuthStatus = str;

type DomainDnsAudit = any;

"""A lookup that finds a value matching `p` (or not, when `want` is false) is "ok"."""
async def:priv check(r: str, label: str, name: str, kind: str, p: str, want: bool = True) -> any {
    out = {"record": r, "label": label, "name": name};
    try {
        found = [v for v in await queryDns(name, kind) if rx(p, "i").test(v.trim()) == want];
        return {**out, "status": "ok" if found else "missing", "found": found};
    } except Exception {
        return {**out, "status": "unknown", "found": []};
    }
}

"""
Independently verifies the public DNS a domain needs, rather than trusting the zone records the
Cloudflare API reports. MX and DMARC are checked at their canonical names, SPF at the names the
sending provider uses; DKIM uses the selector the sending subdomain was provisioned with. A name
that resolves is "ok", one that answers NXDOMAIN is "missing", and a failed lookup "unknown".
"""
async def auditDomainDns(hostname: str, view: any, sendingProvider: any = None) -> any {
    routing = view["routing"];
    resend = sendingProvider == "resend";
    txt = lambda (r: any) -> bool { globalThis.String(at(r, "type", "")).toUpperCase() == "TXT" };
    records = [*routing["records"], *routing["missing"], *view["sending"]];
    keyed = [r for r in records if txt(r) and rx("_domainkey", "i").test(at(r, "name", ""))];
    # Cloudflare reports the selector it signs with, more reliable than guessing from the
    # subdomain's DNS records (whose names may be relative).
    selector = at(view, "dkimSelector");
    fallback = f"resend._domainkey.{hostname}" if resend else None;
    dkim_name = either(at(first(keyed), "name"), fallback);
    dkim_name = f"{selector}._domainkey.{hostname}" if selector else dkim_name;
    # Resend puts SPF on its return-path subdomains, `send.` (a TXT, or a CNAME to one) and, on
    # newer domains, `rsend.`; never on the apex.
    spf_names = [hostname, f"send.{hostname}", f"rsend.{hostname}"] if resend else [hostname];
    lookups: list[any] = [check("mx", "MX", hostname, "MX", r"^0\s*\.?$", False)];
    lookups.extend([check("spf", "SPF", name, "TXT", "v=spf1") for name in spf_names]);
    lookups.append(check("dmarc", "DMARC", f"_dmarc.{hostname}", "TXT", "v=DMARC1"));
    found: any = await globalThis.Promise.all(lookups);
    (mx, spfs, dmarc) = (found[0], found[1:-1], found[-1]);
    # The first SPF name with a match wins; a failed lookup counts only when nothing else answered.
    having = lambda (status: str) -> list[any] { [x for x in spfs if x["status"] == status] };
    spf = first(having("ok") + having("unknown") + spfs[:1]);
    star = {"record": "dkim", "label": "DKIM", "name": f"*._domainkey.{hostname}"};
    dkim = await check("dkim", "DKIM", dkim_name, "TXT", "") if dkim_name else star;
    dkim = dkim if dkim_name else {**star, "status": "unknown", "found": []};
    return {"mx": mx, "spf": spf, "dkim": dkim, "dmarc": dmarc};
}
