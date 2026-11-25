glob:priv URL_RE: any = rx(r"https?:\/\/[^\s<>\x22']+", "gi"),
          WORD: any = rx(r"[\p{L}\p{N}][\p{L}\p{N}_$%.-]{1,48}", "gu"),
          SUBJECT_WORD: any = rx(r"[\p{L}\p{N}]{2,40}", "gu"),
          EDGE_PUNCTUATION: any = rx(r"^[._-]+|[._-]+$", "g"),
          WWW: any = rx(r"^www\."),
          SPACES: any = rx(r"\s+", "g"),
          DIGITS: any = rx(r"\d+", "g"),
          MAX_TEXT: int = 250000;

"""Every match of a global regex in `text`."""
def:priv found_all(text: any, regex: any) -> list[any] {
    return [found[0] for found in globalThis.Array.from(text.matchAll(regex))];
}

def getDomain(value: any = None) -> str {
    address = getEmailAddress(either(value, "")).lower();
    return address.rsplit("@", 1)[1] if "@" in address else "";
}

"""Host names of the links in the text and HTML, without `www.`, at most 50."""
def extractUrlDomains(message: any) -> list[str] {
    source: any = f"{at(message, 'text', '')}\n{at(message, 'html', '')}";
    result: list[str] = [];
    for link in found_all(source.slice(0, MAX_TEXT), URL_RE) {
        try {
            domain = rx_sub(new(globalThis.URL, link).hostname.toLowerCase(), WWW, "");
            if domain and domain not in result {
                result.append(domain);
            }
        } except Exception {}
        if len(result) >= 50 {
            break;
        }
    }
    return result;
}

def prepareSpamContent(message: any) -> dict[str, any] {
    visible: any = f"{at(message, 'subject', '')}\n{at(message, 'text', '')}\n{htmlToReadableText(at(message, 'html'))}";
    return {"visibleText": visible.slice(0, MAX_TEXT), "urlDomains": extractUrlDomains(message)};
}

def tokenizeMessage(message: any, prepared: any = None) -> list[str] {
    prepared = prepareSpamContent(message) if prepared is None else prepared;
    sender = getEmailAddress(at(message, "fromAddr", "")).lower();
    sender_domain = getDomain(sender);
    # A dict as an ordered set.
    tokens: dict[str, bool] = {};
    for raw in found_all(prepared["visibleText"].toLowerCase(), WORD) {
        token: any = rx_sub(raw, EDGE_PUNCTUATION, "");
        if 2 <= token.length <= 50 {
            tokens[token] = True;
        }
        if len(tokens) >= MAX_CANDIDATE_TOKENS {
            break;
        }
    }
    (subject, text) = (at(message, "subject"), at(message, "text"));
    if subject {
        for raw in found_all(subject.toLowerCase(), SUBJECT_WORD) {
            tokens[f"SUBJECT:{raw}"] = True;
        }
    }
    if sender {
        tokens[f"FROM:{sender}"] = True;
    }
    if sender_domain {
        tokens[f"FROM_DOMAIN:{sender_domain}"] = True;
    }
    for domain in prepared["urlDomains"] {
        tokens[f"URL_DOMAIN:{domain}"] = True;
    }
    if at(message, "html") and not (text and text.trim()) {
        tokens["HTML_ONLY"] = True;
    }
    if message["attachments"].length {
        tokens["HAS_ATTACHMENT"] = True;
    }
    return list(tokens)[:MAX_CANDIDATE_TOKENS];
}

"""Lower-cased, whitespace runs as one space, trimmed, cut to `limit` characters."""
def:priv squashed(text: any, limit: int) -> str {
    squeezed: any = rx_sub(text, SPACES, " ");
    return squeezed.trim().slice(0, limit);
}

"""FNV-1a over subject, sender domain, link domains and the text with its digits masked, as 8 hex digits."""
def buildFingerprint(message: any, prepared: any = None) -> str {
    prepared = prepareSpamContent(message) if prepared is None else prepared;
    domains = globalThis.Array.prototype.sort.call(globalThis.Array.from(prepared["urlDomains"]));
    normalized: any = "|".join([
        squashed(at(message, "subject", "").toLowerCase(), 160),
        getDomain(at(message, "fromAddr")),
        ",".join(domains),
        squashed(rx_sub(prepared["visibleText"].toLowerCase(), DIGITS, "#"), 500),
    ]);
    h = 2166136261;
    for index in range(normalized.length) {
        h = globalThis.Math.imul(h ^ normalized.charCodeAt(index), 16777619);
    }
    unsigned: any = h + 4294967296 if h < 0 else h;
    return unsigned.toString(16).padStart(8, "0");
}
