# What a provider recorded about a message: `{verdicts?, senderIp?}`.
type ProviderTrace = dict[str, any];

glob:priv HEADER_SCAN_BYTES: int = 64 * 1024,
          # Headers SES prepends when it accepts a message; the trace ends at the first header it did not write.
          SES_HEADERS: list[str] = [
              "return-path",
              "received",
              "received-spf",
              "authentication-results",
              "x-ses-receipt",
              "x-ses-dkim-signature",
              "x-ses-spam-verdict",
              "x-ses-virus-verdict",
          ],
          # Headers a provider has not vouched for: nothing the sender wrote here may count as authentication.
          UNTRUSTED_PROVIDER_HEADERS: list[str] = [
              "authentication-results",
              "received-spf",
              "arc-authentication-results",
              "received",
              "return-path",
              "x-ses-receipt",
              "x-ses-spam-verdict",
              "x-ses-virus-verdict",
              "x-ses-dkim-signature",
          ],
          MAX_HEADER_ENTRIES: int = 200,
          MAX_HEADER_VALUE: int = 2000;

glob:priv HEADER_END: any = rx(r"\r?\n\r?\n"),
          LINE_BREAK: any = rx(r"\r?\n"),
          FOLDED: any = rx(r"^[ \t]"),
          FROM_SES: any = rx(r"^amazonses\.com\s*;", "i"),
          PASSING: any = rx(r"^(?:spf|dkim)\s*=\s*pass\b", "i"),
          IS_SPF: any = rx(r"^spf\s*=", "i"),
          CLIENT_IP: any = rx(r"\bclient-ip\s*=\s*([^\s;)]+)", "i"),
          SENDER_IP: any = rx(r"\(sender IP is ([^\s;)]+)\)", "i"),
          MAIL_FROM: any = rx(r"\bsmtp\.mailfrom\s*=\s*([^\s;)]+)", "i"),
          ENVELOPE_FROM: any = rx(r"\benvelope-from\s*=\s*([^\s;)]+)", "i"),
          HEADER_D: any = rx(r"\bheader\.d\s*=\s*([^\s;)]+)", "i"),
          HEADER_I: any = rx(r"\bheader\.i\s*=\s*@?([^\s;)]+)", "i"),
          HEADER_FROM: any = rx(r"\bheader\.from\s*=\s*([^\s;)]+)", "i"),
          TLS_VERSION: any = rx(r"\bversion\s*=\s*(TLS(?:v|_)?[\d.]+)", "i"),
          TLS_PREFIX: any = rx(r"^TLSv?", "i"),
          UNDERSCORES: any = rx("_", "g"),
          LEADING_AT: any = rx(r"^@"),
          ANGLES: any = rx(r"^<|>$", "g");

"""The header block as `[name, value]` pairs, names lower-cased, folded lines joined."""
def:priv read_header_lines(raw: any) -> list[any] {
    text: any = new(globalThis.TextDecoder).decode(
        raw.slice(0, globalThis.Math.min(raw.byteLength, HEADER_SCAN_BYTES))
    );
    end = text.search(HEADER_END);
    block = text if end == -1 else text.slice(0, end);
    headers: list[any] = [];
    for line in globalThis.String.prototype.split.call(block, LINE_BREAK) {
        if FOLDED.test(line) and headers {
            headers[-1][1] += " " + line.trim();
            continue;
        }
        colon = line.indexOf(":");
        if colon > 0 {
            headers.append([
                line.slice(0, colon).trim().toLowerCase(),
                line.slice(colon + 1).trim(),
            ]);
        }
    }
    return headers;
}

"""The leading run of headers SES wrote, or None when the message did not come through SES.

Reading stops at the first header SES did not add, so a sender cannot forge an authentication
result further down the message.
"""
def:priv read_ses_headers(raw: any) -> any {
    leading: list[any] = [];
    for header in read_header_lines(raw) {
        if header[0] not in SES_HEADERS {
            break;
        }
        leading.append(header);
    }
    return leading if "x-ses-receipt" in [header[0] for header in leading] else None;
}

def:priv header_value(headers: list[any], name: str) -> any {
    for header in headers {
        if header[0] == name {
            return header[1];
        }
    }
    return None;
}

def:priv sender_ip_of(received: any) -> any {
    return either(extractSenderIp({"received": received}), None) if received else None;
}

"""The verdicts and connecting IP SES recorded in the headers it prepended (Resend receives through SES too).

Without an `X-SES-Receipt` in that leading run nothing is trusted.
"""
def readSesTrace(raw: any) -> any {
    leading = read_ses_headers(raw);
    if leading is None {
        return record({});
    }
    verdicts: dict[str, str] = {};
    results = header_value(leading, "authentication-results");
    if results and FROM_SES.test(results) {
        for method in ["spf", "dkim", "dmarc"] {
            found = rx(f"(?:^|[;\\s]){method}=([a-z]+)", "i").exec(results);
            if found {
                verdicts[method] = found[1].toUpperCase();
            }
        }
    }
    for (key, name) in [("spam", "x-ses-spam-verdict"), ("virus", "x-ses-virus-verdict")] {
        value = header_value(leading, name);
        if value {
            verdicts[key] = value.toUpperCase();
        }
    }
    return record({
        "verdicts": verdicts or None,
        "senderIp": sender_ip_of(header_value(leading, "received")),
    });
}

"""Split an Authentication-Results value on semicolons outside comment parentheses."""
def:priv split_results(value: str) -> list[any] {
    sections: list[any] = [];
    current: any = "";
    depth = 0;
    for ch in value + ";" {
        if ch == "(" {
            depth += 1;
        } elif ch == ")" {
            depth = max(0, depth - 1);
        }
        if ch == ";" and depth == 0 {
            if current.trim() {
                sections.append(current.trim());
            }
            current = "";
            continue;
        }
        current += ch;
    }
    if current.trim() {
        sections.append(current.trim());
    }
    return sections;
}

def:priv method_sections(sections: list[any], method: str) -> list[any] {
    starts = rx(f"^{method}\\s*=", "i");
    return [section for section in sections if starts.test(section)];
}

"""Prefer a passing signature when a message carries more than one of the same method."""
def:priv method_section(sections: list[any], method: str) -> any {
    matches = method_sections(sections, method);
    passes = rx(f"^{method}\\s*=\\s*pass\\b", "i");
    passing = [section for section in matches if passes.test(section)];
    return (passing or matches or [None])[0];
}

def:priv method_status(section: any, method: str) -> any {
    found = rx(f"^{method}\\s*=\\s*([a-z]+)", "i").exec(section) if section else None;
    return found[1].toUpperCase() if found else None;
}

"""Group 1 of the first of `patterns` that matches `section`; None when none does."""
def:priv first_group(section: any, *patterns: any) -> any {
    if not section {
        return None;
    }
    for pattern in patterns {
        found = pattern.exec(section);
        if found {
            return found[1];
        }
    }
    return None;
}

"""A domain from either `d=`/`smtp.mailfrom=` (a domain) or `i=` (a mailbox)."""
def:priv domain_from_identity(value: any) -> any {
    if not value {
        return None;
    }
    stripped: any = rx_sub(rx_sub(value, LEADING_AT, ""), ANGLES, "");
    cleaned = stripped.trim().toLowerCase();
    return cleaned.slice(cleaned.lastIndexOf("@") + 1) or None;
}

def:priv mailed_by(section: any) -> any {
    return domain_from_identity(first_group(section, MAIL_FROM, ENVELOPE_FROM));
}

def:priv signed_by(section: any) -> any {
    return domain_from_identity(first_group(section, HEADER_D, HEADER_I));
}

def:priv tls_version(received: any) -> any {
    version = first_group(received, TLS_VERSION);
    return rx_sub(rx_sub(version, TLS_PREFIX, "TLS "), UNDERSCORES, ".") if version else NULL;
}

def:priv sender_domain_matches(from_address: any, domains: list[any]) -> any {
    from_domain = from_address.slice(from_address.lastIndexOf("@") + 1).trim().toLowerCase();
    if not from_domain or not domains {
        return NULL;
    }
    return bool([domain for domain in domains if isSameOrSubdomain(domain, from_domain)]);
}

def:priv method_result(status: any, detail: any) -> any {
    return {"status": status, "detail": either(detail, NULL)} if status else NULL;
}

"""Authentication results for a message that arrived through SES.

Returns null when the message has no trusted provider trace, so callers can say results are
unavailable instead of trusting headers the sender could have written.
"""
def readSesAuthentication(raw: any, fromAddress: str) -> any {
    leading = read_ses_headers(raw);
    if leading is None {
        return NULL;
    }
    results = header_value(leading, "authentication-results");
    if not results or not FROM_SES.test(results) {
        return NULL;
    }
    sections = split_results(results);
    (spf, dkim, dmarc) = (
        method_section(sections, "spf"),
        method_section(sections, "dkim"),
        method_section(sections, "dmarc"),
    );
    (spf_status, dkim_status, dmarc_status) = (
        method_status(spf, "spf"),
        method_status(dkim, "dkim"),
        method_status(dmarc, "dmarc"),
    );
    if not spf_status and not dkim_status and not dmarc_status {
        return NULL;
    }
    spf_ip = first_group(spf, CLIENT_IP, SENDER_IP);
    (mailer, signer) = (mailed_by(spf), signed_by(dkim));
    dmarc_from = first_group(dmarc, HEADER_FROM);
    dmarc_domain = dmarc_from.toLowerCase() if dmarc_from else None;
    # Only passing signatures say anything about alignment; a failing one must not make an
    # unrelated sender look aligned.
    aligned = [
        mailed_by(section) if IS_SPF.test(section) else signed_by(section)
        for section in method_sections(sections, "spf") + method_sections(sections, "dkim")
        if PASSING.test(section)
    ];
    received = header_value(leading, "received");
    spf_detail = f"IP {spf_ip}" if spf_ip else (f"mailed by {mailer}" if mailer else None);
    return record({
        "spf": method_result(spf_status, spf_detail),
        "dkim": method_result(dkim_status, f"d={signer}" if signer else None),
        "dmarc": method_result(
            dmarc_status, f"header.from={dmarc_domain}" if dmarc_domain else None
        ),
        "signedBy": either(signer, NULL),
        "mailedBy": either(mailer, NULL),
        "senderIp": either(spf_ip, extractSenderIp({"received": received}) if received else NULL),
        "encryption": tls_version(received),
        "aligned": sender_domain_matches(fromAddress, [domain for domain in aligned if domain]),
    });
}

"""A bounded header map (lower-case names, first value wins) for providers that do not hand one over.

Auto-reply suppression and spam analysis can so see Auto-Submitted, Precedence, List-Id and similar.
"""
def readHeaderMap(raw: any) -> any {
    found: any = globalThis.Object();
    count = 0;
    for (name, value) in read_header_lines(raw) {
        # `Reflect.has` as JavaScript's `in`: a header named like an Object.prototype member is skipped.
        if name in UNTRUSTED_PROVIDER_HEADERS or globalThis.Reflect.has(found, name) {
            continue;
        }
        found[name] = value.slice(0, MAX_HEADER_VALUE);
        count += 1;
        if count >= MAX_HEADER_ENTRIES {
            break;
        }
    }
    return found;
}
