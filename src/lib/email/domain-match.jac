def:priv clean(name: str) -> str {
    return name.strip().lower().removesuffix(".");
}

"""Same owner: equal domains, or one a subdomain of the other.

Names that only share a suffix (`victim.co.ke`, `attacker.co.ke`) are independent
registrations, and two sibling subdomains count as different.
"""
def isSameOrSubdomain(a: str, b: str) -> bool {
    (left, right) = (clean(a), clean(b));
    return bool(left and right)
        and (left == right or left.endswith(f".{right}") or right.endswith(f".{left}"));
}
