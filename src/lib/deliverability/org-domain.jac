import from "tldts" { getDomain }

glob:priv HOST: any = rx(
              r"^(?=.{1,253}$)(?:[a-z0-9_](?:[a-z0-9_-]{0,61}[a-z0-9_])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$",
          ),
          ROOT_DOT: any = rx(r"\.$");

"""
Organisational domain from the Public Suffix List, private suffixes included (`example.eu.org`, `alice.github.io`),
so tenants of a shared suffix are never one organisation. A host that is itself a public suffix, an IP address or
has no valid name gives null.
"""
def organisationalDomain(host: any) -> any {
    name = rx_sub(host.trim().toLowerCase(), ROOT_DOT, "");
    if not HOST.test(name) {
        return NULL;
    }
    return getDomain(name, record({"allowPrivateDomains": True}));
}

"""The organisational domain of the one address in a `From` header or contact email, or null when there is not exactly one."""
def addressOrganisation(value: any = None) -> any {
    addresses = getEmailAddressList(value);
    if len(addresses) != 1 or "@" not in addresses[0] {
        return NULL;
    }
    return organisationalDomain(addresses[0].rsplit("@", 1)[1]);
}
