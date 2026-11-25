# Cloudflare Email Routing writes its verdicts under this authserv-id.
glob:priv TRUSTED_AUTHSERV_ID: str = "mx.cloudflare.net",
          METHODS: list[str] = ["dmarc", "dkim", "spf"],
          CLAUSE_START: any = rx(r",\s*(?=[a-z0-9-]+(?:\.[a-z0-9-]+)+\s*;)", "i");

def:priv method_signal(method: str, result: any) -> any {
    if result not in ["pass", "fail"] {
        return None;
    }
    (outcome, weight) = ("passed", "Pass") if result == "pass" else ("failed", "Fail");
    return {
        "id": f"{method}_{outcome}",
        "score": SPAM_WEIGHTS.authentication[f"{method}{weight}"],
        "reason": f"{method.upper()} authentication {outcome}",
    };
}

"""
A sender can add Authentication-Results lines of its own, and duplicate headers arrive joined, so look at
every clause: only Cloudflare's exact authserv-id counts, a failure in any clause wins, and a pass needs all
of them to agree. A forged pass can then never hide a real fail.
"""
def:priv trusted_header_results(headers: any) -> dict[str, any] {
    value = findHeader(headers, "authentication-results");
    if not value {
        return {};
    }
    seen: dict[str, list[str]] = {method: [] for method in METHODS};
    for clause in globalThis.String.prototype.split.call(value, CLAUSE_START) {
        if clause.split(";")[0].trim().toLowerCase() != TRUSTED_AUTHSERV_ID {
            continue;
        }
        for method in METHODS {
            found = rx(f"(?:^|[;\\s]){method}=([a-z]+)", "i").exec(clause);
            if found {
                seen[method].append(found[1].toLowerCase());
            }
        }
    }
    return {
        method: "fail"
            if "fail" in results
            else "pass" if results and all([result == "pass" for result in results]) else None
        for (method, results) in seen.items()
    };
}

"""True when the receiving provider gave any verdict of its own, which then replaces the headers."""
def:priv has_verdicts(verdicts: any) -> bool {
    return bool(verdicts)
        and any([bool(at(verdicts, name)) for name in ["spf", "dkim", "dmarc", "spam"]]);
}

def:priv verdict(verdicts: any, name: str) -> any {
    value = at(verdicts, name);
    return value.toLowerCase() if value else None;
}

"""The receiving side's own DMARC verdict for a message, by the same trust rules spam analysis uses."""
def readTrustedDmarcResult(headers: any = None, verdicts: any = None) -> any {
    if has_verdicts(verdicts) {
        result = verdict(verdicts, "dmarc");
        return result if result in ["pass", "fail"] else None;
    }
    return trusted_header_results(headers).get("dmarc");
}

"""
SPF, DKIM and DMARC results. Verdicts from the receiving provider (SES) win; otherwise only an
Authentication-Results clause written by Cloudflare is read. Self-hosted SMTP verifies SPF, DKIM
and DMARC itself (server/runtime/smtp-auth.ts) and passes the outcome in as verdicts.
"""
def analyzeAuthentication(headers: any = None, verdicts: any = None) -> list[any] {
    provided = has_verdicts(verdicts);
    results = {method: verdict(verdicts, method) for method in METHODS}
        if provided
        else trusted_header_results(headers);
    signals = [
        signal
        for method in METHODS
        if (signal := method_signal(method, results.get(method)))
    ];
    if provided and verdict(verdicts, "spam") == "fail" {
        signals.append({
            "id": "provider_spam_verdict",
            "score": SPAM_WEIGHTS.provider.spamVerdict,
            "reason": "The receiving mail provider classified this message as spam",
        });
    }
    return signals;
}
