# What a provider recorded about a message: `{verdicts?, senderIp?}`.
type ProviderTrace = any;

# SES_HEADERS: what SES prepends when it accepts a message; its trace ends at the first other one.
# UNTRUSTED: headers no provider vouched for, so nothing the sender wrote there counts.
glob:priv SES_HEADERS: list[str] = """return-path received received-spf authentication-results
              x-ses-receipt x-ses-dkim-signature x-ses-spam-verdict x-ses-virus-verdict""".split(),
          UNTRUSTED: list[str] = SES_HEADERS + ["arc-authentication-results"],
          FROM_SES: any = rx(r"^amazonses\.com\s*;", "i"),
          CLIENT_IP: any = rx(r"\bclient-ip\s*=\s*([^\s;)]+)", "i"),
          SENDER_IP: any = rx(r"\(sender IP is ([^\s;)]+)\)", "i"),
          MAIL_FROM: any = rx(r"\bsmtp\.mailfrom\s*=\s*([^\s;)]+)", "i"),
          ENVELOPE_FROM: any = rx(r"\benvelope-from\s*=\s*([^\s;)]+)", "i"),
          HEADER_D: any = rx(r"\bheader\.d\s*=\s*([^\s;)]+)", "i"),
          HEADER_I: any = rx(r"\bheader\.i\s*=\s*@?([^\s;)]+)", "i"),
          HEADER_SCAN_BYTES: int = 64 * 1024,
          MAX_HEADER_ENTRIES: int = 200,
          MAX_HEADER_VALUE: int = 2000;

# The header block as `[name, value]` pairs, names lower-cased, folded lines joined.
def:priv read_header_lines(raw: any) -> list[any] {
    n = globalThis.Math.min(raw.byteLength, HEADER_SCAN_BYTES);
    text: any = new(globalThis.TextDecoder).decode(raw.slice(0, n));
    end = text.search(rx(r"\r?\n\r?\n"));
    (block, headers) = (text if end == -1 else text.slice(0, end), []);
    for line in globalThis.String.prototype.split.call(block, rx(r"\r?\n")) {
        colon = line.indexOf(":");
        if rx(r"^[ \t]").test(line) and headers {
            headers[-1][1] += " " + line.trim();
        } elif colon > 0 {
            (k, v) = (line.slice(0, colon), line.slice(colon + 1));
            headers.append([k.trim().toLowerCase(), v.trim()]);
        }
    }
    return headers;
}

# The leading run of headers SES wrote, None unless it holds an X-SES-Receipt. Reading stops at the
# first header SES did not add, so a sender cannot forge a result further down.
def:priv read_ses_headers(raw: any) -> any {
    leading: list[any] = [];
    for h in read_header_lines(raw) {
        if h[0] not in SES_HEADERS {
            break;
        }
        leading.append(h);
    }
    return leading if any(h[0] == "x-ses-receipt" for h in leading) else None;
}

def:priv header_value(headers: list[any], name: str) -> any {
    return next((h[1] for h in headers if h[0] == name), None);
}

# The verdicts and connecting IP SES recorded in the headers it prepended (Resend receives through
# SES too). Without an `X-SES-Receipt` in that leading run nothing is trusted.
def readSesTrace(raw: any) -> any {
    leading = read_ses_headers(raw);
    if leading is None {
        return record({});
    }
    verdicts: dict[str, str] = {};
    results = header_value(leading, "authentication-results");
    for method in ["spf", "dkim", "dmarc"] if results and FROM_SES.test(results) else [] {
        found = rx(f"(?:^|[;\\s]){method}=([a-z]+)", "i").exec(results);
        if found {
            verdicts[method] = found[1].toUpperCase();
        }
    }
    for key in ["spam", "virus"] {
        if (v := header_value(leading, f"x-ses-{key}-verdict")) {
            verdicts[key] = v.toUpperCase();
        }
    }
    received = header_value(leading, "received");
    ip = either(extractSenderIp({"received": received}), None) if received else None;
    return record({"verdicts": verdicts or None, "senderIp": ip});
}

# Split an Authentication-Results value on semicolons outside comment parentheses.
def:priv split_results(value: str) -> list[any] {
    (sections, current, depth) = ([], "", 0);
    for ch in value {
        depth = globalThis.Math.max(0, depth + {"(": 1, ")": -1}.get(ch, 0));
        if ch == ";" and depth == 0 {
            (sections, current) = (sections + [current], "");
        } else {
            current += ch;
        }
    }
    return [s.trim() for s in sections + [current] if s.trim()];
}

def:priv method_sections(sections: list[any], method: str) -> list[any] {
    return [s for s in sections if rx(f"^{method}\\s*=", "i").test(s)];
}

# Prefer a passing signature when a message carries more than one of the same method.
def:priv method_section(sections: list[any], method: str) -> any {
    matches = method_sections(sections, method);
    passing = [s for s in matches if rx(f"^{method}\\s*=\\s*pass\\b", "i").test(s)];
    return (passing or matches or [None])[0];
}

def:priv method_status(section: any, method: str) -> any {
    status = first_group(section, rx(f"^{method}\\s*=\\s*([a-z]+)", "i"));
    return status.toUpperCase() if status else None;
}

# Group 1 of the first of `patterns` that matches `section`; None when none does.
def:priv first_group(section: any, *patterns: any) -> any {
    found = [p.exec(section) for p in patterns] if section else [];
    return next((f[1] for f in found if f), None);
}

# A domain from either `d=`/`smtp.mailfrom=` (a domain) or `i=` (a mailbox).
def:priv domain_from_identity(value: any) -> any {
    cleaned: any = rx_sub(rx_sub(value or "", rx(r"^@"), ""), rx(r"^<|>$", "g"), "");
    cleaned = cleaned.trim().toLowerCase();
    return cleaned.slice(cleaned.lastIndexOf("@") + 1) or None;
}

def:priv mailed_by(section: any) -> any {
    return domain_from_identity(first_group(section, MAIL_FROM, ENVELOPE_FROM));
}

def:priv signed_by(section: any) -> any {
    return domain_from_identity(first_group(section, HEADER_D, HEADER_I));
}

def:priv tls_version(received: any) -> any {
    v = first_group(received, rx(r"\bversion\s*=\s*(TLS(?:v|_)?[\d.]+)", "i"));
    return rx_sub(rx_sub(v, rx(r"^TLSv?", "i"), "TLS "), rx("_", "g"), ".") if v else NULL;
}

def:priv method_result(status: any, detail: any) -> any {
    return {"status": status, "detail": either(detail, NULL)} if status else NULL;
}

# Authentication results for a message that arrived through SES, null without a trusted provider
# trace, so callers say results are unavailable instead of trusting what the sender wrote.
def readSesAuthentication(raw: any, fromAddress: any) -> any {
    leading = read_ses_headers(raw);
    results = header_value(leading, "authentication-results") if leading else None;
    if not results or not FROM_SES.test(results) {
        return NULL;
    }
    sections = split_results(results);
    methods = ["spf", "dkim", "dmarc"];
    (spf, dkim, dmarc) = [method_section(sections, m) for m in methods];
    (spf_s, dkim_s, dmarc_s) = [method_status(method_section(sections, m), m) for m in methods];
    if not spf_s and not dkim_s and not dmarc_s {
        return NULL;
    }
    spf_ip = first_group(spf, CLIENT_IP, SENDER_IP);
    (mailer, signer) = (mailed_by(spf), signed_by(dkim));
    dmarc_from = first_group(dmarc, rx(r"\bheader\.from\s*=\s*([^\s;)]+)", "i"));
    dmarc_domain = dmarc_from.toLowerCase() if dmarc_from else None;
    # Only passing signatures say anything about alignment; a failing one must not make an
    # unrelated sender look aligned.
    aligned = [
        mailed_by(s) if rx(r"^spf\s*=", "i").test(s) else signed_by(s)
        for s in method_sections(sections, "spf") + method_sections(sections, "dkim")
        if rx(r"^(?:spf|dkim)\s*=\s*pass\b", "i").test(s)
    ];
    aligned = [d for d in aligned if d];
    from_domain: any = fromAddress.slice(fromAddress.lastIndexOf("@") + 1).trim().toLowerCase();
    matched = any(isSameOrSubdomain(d, from_domain) for d in aligned);
    received = header_value(leading, "received");
    spf_detail = f"IP {spf_ip}" if spf_ip else (f"mailed by {mailer}" if mailer else None);
    return record({
        "spf": method_result(spf_s, spf_detail),
        "dkim": method_result(dkim_s, f"d={signer}" if signer else None),
        "dmarc": method_result(dmarc_s, f"header.from={dmarc_domain}" if dmarc_domain else None),
        "signedBy": either(signer, NULL),
        "mailedBy": either(mailer, NULL),
        "senderIp": either(spf_ip, extractSenderIp({"received": received}) if received else NULL),
        "encryption": tls_version(received),
        "aligned": matched if from_domain and aligned else NULL,
    });
}

# A bounded header map (lower-case names, first value wins) for providers that hand none over, so
# auto-reply suppression and spam analysis see Auto-Submitted, Precedence, List-Id and similar.
def readHeaderMap(raw: any) -> any {
    (found, count) = (globalThis.Object(), 0);
    for (name, value) in read_header_lines(raw) {
        # `Reflect.has` as JavaScript's `in`: a header named like an Object.prototype member is skipped.
        if name not in UNTRUSTED and not globalThis.Reflect.has(found, name) {
            found[name] = value.slice(0, MAX_HEADER_VALUE);
            count += 1;
            if count >= MAX_HEADER_ENTRIES {
                break;
            }
        }
    }
    return found;
}
