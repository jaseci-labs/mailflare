# Same owner: equal domains, or one a subdomain of the other. Names that only share a suffix
# (`victim.co.ke`, `attacker.co.ke`) are independent registrations; sibling subdomains differ.
def isSameOrSubdomain(a: str, b: str) -> bool {
    (l, r) = [x.strip().lower().removesuffix(".") for x in [a, b]];
    return bool(l and r) and (l == r or l.endswith(f".{r}") or r.endswith(f".{l}"));
}
