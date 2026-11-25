# Each entry is one kind of search-optimisation or traffic pitch; a message must match at least two kinds.
glob:priv PITCH_PATTERNS: list[any] = [
              rx(
                  r"\b(?:submit|list|add|register)\b[^\n]{0,70}\bto\b[^\n]{0,20}\bsearch engines?\b",
                  "i",
              ),
              rx(
                  r"\b(?:rank(?:ing|ings)?|first page|page one|top (?:spot|position|results?))\b[^.\n]{0,40}\bgoogle\b",
                  "i",
              ),
              rx(r"\b(?:quality |cheap |high[- ]da |premium )?backlinks?\b", "i"),
              rx(
                  r"\b(?:boost|increase|improve|grow|drive)\b[^.\n]{0,30}\b(?:traffic|rankings?|visibility|seo)\b",
                  "i",
              ),
              rx(r"\bseo (?:audit|services?|packages?|report|expert|specialist|campaign)\b", "i"),
              rx(r"\bguaranteed (?:rankings?|traffic|results|visitors)\b", "i"),
          ],
          REGEX_SPECIAL: any = rx(r"[.*+?^${}()|[\]\\]", "g");

"""Bare domains the recipient could be addressed at, from To and Cc."""
def:priv recipient_domains(message: any) -> list[str] {
    domains = [
        getDomain(part)
        for part in f"{at(message, 'toAddr', '')},{at(message, 'ccAddr', '')}".split(",")
    ];
    return [registrableDomain(domain) for domain in domains if "." in domain];
}

"""True when the text names `domain` as a site, not as part of an email address such as the recipient's own."""
def:priv mentions(text: str, domain: str) -> bool {
    escaped = rx_sub(domain, REGEX_SPECIAL, "\\$&");
    return rx(f"(?<![\\w.@-])(?:www\\.)?{escaped}(?![\\w-])", "i").test(text);
}

"""
Cold outreach selling search or traffic services for the recipient's own site. Deliberately narrow: it only
fires for a first-contact sender, a message that is not a reply and carries no List-Unsubscribe header,
names the recipient's registrable domain, and matches two different pitch patterns.
"""
def analyzeSolicitation(message: any, prepared: any, options: any) -> list[any] {
    if not options["firstContact"]
        or options["hasUnsubscribe"]
        or at(message, "inReplyTo")
        or message["references"].length > 0
    {
        return [];
    }
    text = prepared["visibleText"];
    if not any([mentions(text, domain) for domain in recipient_domains(message)])
        or len([pattern for pattern in PITCH_PATTERNS if pattern.test(text)]) < 2
    {
        return [];
    }
    return [
        {
            "id": "unsolicited_solicitation",
            "score": SPAM_WEIGHTS.content.coldSolicitation,
            "reason": "First-time sender is pitching search or traffic services for your own website",
        },
    ];
}
