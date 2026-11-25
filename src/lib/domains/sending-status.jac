"""The sending subdomain named exactly `hostname`, else the first wildcard (`*.base`) covering it"""
def findSendingSubdomain(hostname: any, subdomains: any) -> any {
    want = hostname.toLowerCase();
    found = [s for s in subdomains if s["name"].toLowerCase() == want];
    for s in subdomains {
        n = s["name"].toLowerCase();
        if n.startswith("*.") and want != n.slice(2) and want.endswith("." + n.slice(2)) {
            found.append(s);
        }
    }
    return either(first(found), NULL);
}
