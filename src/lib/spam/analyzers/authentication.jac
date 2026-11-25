# Cloudflare Email Routing writes its verdicts under this authserv-id.
glob:priv TRUSTED: str = "mx.cloudflare.net",
          METHODS: list[str] = ["dmarc", "dkim", "spf"];

def:priv method_signal(m: str, result: any) -> any {
    if result not in ["pass", "fail"] {
        return None;
    }
    (o, weight) = ("passed", "Pass") if result == "pass" else ("failed", "Fail");
    score = SPAM_WEIGHTS.authentication[m + weight];
    return {"id": f"{m}_{o}", "score": score, "reason": f"{m.upper()} authentication {o}"};
}

# A sender can add Authentication-Results lines of its own and duplicates arrive joined, so every
# clause counts: only Cloudflare's exact authserv-id, a fail anywhere wins, a pass needs them all.
def:priv trusted(headers: any) -> dict[str, any] {
    value = findHeader(headers, "authentication-results") or "";
    clause = rx(r",\s*(?=[a-z0-9-]+(?:\.[a-z0-9-]+)+\s*;)", "i");
    every = globalThis.String.prototype.split.call(value, clause);
    clauses = [c for c in every if c.split(";")[0].trim().toLowerCase() == TRUSTED];
    pick = lambda (m: str, c: any) -> any { rx(f"(?:^|[;\\s]){m}=([a-z]+)", "i").exec(c) };
    seen = {m: [f[1].toLowerCase() for c in clauses if (f := pick(m, c))] for m in METHODS};
    rule = lambda (x: any) -> any {
        "fail" if "fail" in x else "pass" if set(x) == {"pass"} else None
    };
    return {m: rule(r) for (m, r) in seen.items()};
}

"""True when the receiving provider gave any verdict of its own, which then replaces the headers."""
def:priv provided(verdicts: any) -> bool {
    return bool(verdicts) and any([bool(at(verdicts, k)) for k in "spf dkim dmarc spam".split()]);
}

def:priv verdict(verdicts: any, name: str) -> any {
    value = at(verdicts, name);
    return value.toLowerCase() if value else None;
}

"""The receiving side's own DMARC verdict for a message, by the trust rules spam analysis uses."""
def readTrustedDmarcResult(headers: any = None, verdicts: any = None) -> any {
    result = verdict(verdicts, "dmarc") if provided(verdicts) else trusted(headers).get("dmarc");
    return result if result in ["pass", "fail"] else None;
}

"""
SPF, DKIM and DMARC results. Verdicts from the receiving provider (SES) win; otherwise only an
Authentication-Results clause written by Cloudflare is read. Self-hosted SMTP verifies SPF, DKIM
and DMARC itself (server/runtime/smtp-auth.ts) and passes the outcome in as verdicts.
"""
def analyzeAuthentication(headers: any = None, verdicts: any = None) -> list[any] {
    given = provided(verdicts);
    results = {m: verdict(verdicts, m) for m in METHODS} if given else trusted(headers);
    signals = [s for m in METHODS if (s := method_signal(m, results[m]))];
    if given and verdict(verdicts, "spam") == "fail" {
        why = "The receiving mail provider classified this message as spam";
        score = SPAM_WEIGHTS.provider.spamVerdict;
        signals.append({"id": "provider_spam_verdict", "score": score, "reason": why});
    }
    return signals;
}
