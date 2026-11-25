# What a provider recorded about a message: `{verdicts?, senderIp?}`.
type ProviderTrace = any;

# SES_HEADERS: what SES prepends when it accepts a message; its trace ends at the first other one.
# UNTRUSTED: headers no provider vouched for, so nothing the sender wrote there counts.
glob:priv SES_HEADER_NAMES: list[str] = """return-path received received-spf authentication-results
              x-ses-receipt x-ses-dkim-signature x-ses-spam-verdict x-ses-virus-verdict""".split(),
          SES_HEADERS: set[str] = set(SES_HEADER_NAMES),
          UNTRUSTED: set[str] = set(SES_HEADER_NAMES + ["arc-authentication-results"]),
          BLANK_LINE: any = rx(r"\r?\n\r?\n"),
          LINE_BREAK: any = rx(r"\r?\n"),
          FOLDED: any = rx(r"^[ \t]"),
          VERDICT_METHODS: list[str] = ["spf", "dkim", "dmarc"],
          VERDICTS: list[any] = [
              rx(f"(?:^|[;\\s]){method}=([a-z]+)", "i")
              for method in VERDICT_METHODS
          ],
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
def:priv read_header_lines(raw: any) -> list[list[str]] {
    n = globalThis.Math.min(raw.byteLength, HEADER_SCAN_BYTES);
    text: str = new(globalThis.TextDecoder).decode(raw.slice(0, n));
    end: int = globalThis.String.prototype.search.call(text, BLANK_LINE);
    block: str = text;
    if end != -1 {
        block = globalThis.String.prototype.slice.call(text, 0, end);
    }
    headers: list[list[str]] = [];
    for piece in globalThis.String.prototype.split.call(block, LINE_BREAK) {
        line: str = piece;
        if globalThis.RegExp.prototype.test.call(FOLDED, line) and headers {
            last: list[str] = headers[-1];
            last[1] = last[1] + " " + globalThis.String.prototype.trim.call(line);
            continue;
        }
        colon: int = globalThis.String.prototype.indexOf.call(line, ":");
        if colon > 0 {
            name: str = globalThis.String.prototype.slice.call(line, 0, colon);
            value: str = globalThis.String.prototype.slice.call(line, colon + 1);
            name = globalThis.String.prototype.trim.call(name);
            name = globalThis.String.prototype.toLowerCase.call(name);
            headers.append([name, globalThis.String.prototype.trim.call(value)]);
        }
    }
    return headers;
}

# The leading run of headers SES wrote, None unless it holds an X-SES-Receipt. Reading stops at the
# first header SES did not add, so a sender cannot forge a result further down.
def:priv read_ses_headers(raw: any) -> list[list[str]] | None {
    leading: list[list[str]] = [];
    receipt = False;
    for h in read_header_lines(raw) {
        if h[0] not in SES_HEADERS {
            break;
        }
        receipt = receipt or h[0] == "x-ses-receipt";
        leading.append(h);
    }
    return leading if receipt else None;
}

def:priv header_value(headers: list[list[str]], name: str) -> any {
    for h in headers {
        if h[0] == name {
            return h[1];
        }
    }
    return None;
}

# The verdicts and connecting IP SES recorded in the headers it prepended (Resend receives through
# SES too). Without an `X-SES-Receipt` in that leading run nothing is trusted.
def readSesTrace(raw: any) -> any {
    found_headers = read_ses_headers(raw);
    if found_headers is None {
        return record({});
    }
    leading: list[list[str]] = found_headers;
    verdicts: dict[str, str] = {};
    results = header_value(leading, "authentication-results");
    if results and globalThis.RegExp.prototype.test.call(FROM_SES, results) {
        for i in range(3) {
            found = globalThis.RegExp.prototype.exec.call(VERDICTS[i], results);
            if found {
                verdicts[VERDICT_METHODS[i]] = found[1].toUpperCase();
            }
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
    found: any = globalThis.Object();
    count: int = 0;
    for h in read_header_lines(raw) {
        name = h[0];
        # `Reflect.has` as JavaScript's `in`: a header named like an Object.prototype member is skipped.
        if name not in UNTRUSTED and not globalThis.Reflect.has(found, name) {
            value: str = globalThis.String.prototype.slice.call(h[1], 0, MAX_HEADER_VALUE);
            globalThis.Reflect.set(found, name, value);
            count += 1;
            if count >= MAX_HEADER_ENTRIES {
                break;
            }
        }
    }
    return found;
}
