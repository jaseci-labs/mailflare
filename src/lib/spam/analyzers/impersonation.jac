"""
Global brands phishing commonly pretends to be, with the owner labels of the domains they really send from.
Regional banks, carriers and telcos are added per installation in the admin spam filter settings.
"""
glob:priv BRANDS: list[tuple[any, list[str]]] = [
              (rx(r"\bpaypal\b", "i"), ["paypal", "paypal-communication", "paypalobjects"]),
              (
                  rx(r"\bapple\b|\bicloud\b|\bitunes\b", "i"),
                  ["apple", "icloud", "me", "mac", "itunes"],
              ),
              (
                  rx(r"\bmicrosoft\b|\boffice ?365\b|\bonedrive\b", "i"),
                  [
                      "microsoft",
                      "office",
                      "office365",
                      "outlook",
                      "live",
                      "hotmail",
                      "microsoftonline",
                      "sharepoint",
                      "onedrive",
                      "azure",
                  ],
              ),
              (rx(r"\bgoogle\b|\bgmail\b", "i"), ["google", "gmail", "googlemail", "youtube"]),
              (rx(r"\bamazon\b|\baws\b", "i"), ["amazon", "amazonaws", "amazonses", "aws"]),
              (rx(r"\bnetflix\b", "i"), ["netflix"]),
              (rx(r"\bdhl\b", "i"), ["dhl"]),
              (rx(r"\bfedex\b", "i"), ["fedex"]),
              (rx(r"\bups\b", "i"), ["ups"]),
              (rx(r"\bdpd\b", "i"), ["dpd"]),
              (rx(r"\brevolut\b", "i"), ["revolut"]),
              (rx(r"\bcoinbase\b", "i"), ["coinbase"]),
              (rx(r"\bbinance\b", "i"), ["binance"]),
              (rx(r"\bdocusign\b", "i"), ["docusign"]),
              (rx(r"\bdropbox\b", "i"), ["dropbox", "dropboxmail"]),
              (rx(r"\blinkedin\b", "i"), ["linkedin"]),
              (
                  rx(r"\bfacebook\b|\bmeta\b|\binstagram\b|\bwhatsapp\b", "i"),
                  ["facebook", "facebookmail", "meta", "metamail", "instagram", "whatsapp"],
              ),
          ],
          REGEX_SPECIAL: any = rx(r"[.*+?^${}()|[\]\\]", "g"),
          SPACES: any = rx(r"\s+", "g"),
          ADDRESS: any = rx(r"[\w.+-]+@([\w-]+(?:\.[\w-]+)+)");

"""An administrator's brand as a matcher: the name as a whole word, spacing optional."""
def:priv custom_brand(brand: any) -> tuple[any, list[str]] {
    name = rx_sub(rx_sub(brand["name"].trim(), REGEX_SPECIAL, "\\$&"), SPACES, "\\s*");
    return (
        rx(f"(?<![\\p{{L}}\\p{{N}}]){name}(?![\\p{{L}}\\p{{N}}])", "iu"),
        [domainOwnerLabel(domain) for domain in brand["domains"]],
    );
}

"""
Sender impersonation: a display name that claims a brand or another address, and sender domains made to
look like a domain the user really corresponds with (`paypa1.com`, `rnicrosoft.com`).
`knownDomains` are domains the user has written to or owns.
"""
def analyzeImpersonation(sender: any, knownDomains: any, customBrands: any = None) -> list[any] {
    sender_domain = getDomain(sender);
    if not sender_domain {
        return [];
    }
    signals: list[any] = [];
    name = either(parseEmailAddressParts(either(sender, ""))["name"], "");
    owner = domainOwnerLabel(sender_domain);
    if name {
        matchers = [custom_brand(brand) for brand in either(customBrands, [])] + BRANDS;
        owners = next((owners for (pattern, owners) in matchers if pattern.test(name)), None);
        if owners is not None
            and not any([
                owner == label or owner.startswith(f"{label}-") or owner.endswith(f"-{label}")
                for label in owners
            ])
        {
            signals.append({
                "id": "brand_display_name",
                "score": SPAM_WEIGHTS.impersonation.brandDisplayName,
                "reason": "The sender name claims a well-known brand the sending domain does not belong to",
                "metadata": {"name": name},
            });
        }
        claimed = ADDRESS.exec(name);
        if claimed
            and registrableDomain(claimed[1].toLowerCase()) != registrableDomain(sender_domain)
        {
            signals.append({
                "id": "address_in_display_name",
                "score": SPAM_WEIGHTS.impersonation.addressInDisplayName,
                "reason": "The sender name shows a different email address than the one the message is from",
            });
        }
    }
    known = [registrableDomain(domain) for domain in knownDomains];
    if registrableDomain(sender_domain) not in known {
        imitated = next(
            (domain for domain in known if isLookalikeDomain(sender_domain, domain)), None
        );
        if imitated {
            signals.append({
                "id": "lookalike_domain",
                "score": SPAM_WEIGHTS.impersonation.lookalikeDomain,
                "reason": f"The sender domain imitates {imitated}, a domain you correspond with",
                "metadata": {"imitated": imitated},
            });
        }
    }
    return signals;
}
