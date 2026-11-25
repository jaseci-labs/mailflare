# Runs on every inbound mail: hoisted regexes, plain loops and JavaScript's own string methods.

# Cloudflare Email Routing writes its verdicts under this authserv-id.
glob:priv TRUSTED: str = "mx.cloudflare.net",
          METHODS: list[str] = ["dmarc", "dkim", "spf"],
          # One Authentication-Results value holds several clauses, each starting with an authserv-id.
          CLAUSE: any = rx(r",\s*(?=[a-z0-9-]+(?:\.[a-z0-9-]+)+\s*;)", "i"),
          RESULT: dict[str, any] = {
              m: rx(f"(?:^|[;\\s]){m}=([a-z]+)", "i")
              for m in ["dmarc", "dkim", "spf"]
          },
          UPPER: dict[str, str] = {"dmarc": "DMARC", "dkim": "DKIM", "spf": "SPF"};

def:priv lower(s: any) -> str {
    return globalThis.String.prototype.toLowerCase.call(s);
}

def:priv method_signal(m: str, result: any) -> any {
    if result == "pass" {
        score = SPAM_WEIGHTS.authentication[m + "Pass"];
        return {"id": m + "_passed", "score": score, "reason": UPPER[m] + " authentication passed"};
    }
    if result == "fail" {
        score = SPAM_WEIGHTS.authentication[m + "Fail"];
        return {"id": m + "_failed", "score": score, "reason": UPPER[m] + " authentication failed"};
    }
    return None;
}

# A sender can add Authentication-Results lines of its own and duplicates arrive joined, so every
# clause counts: only Cloudflare's exact authserv-id.
def:priv trusted_clauses(headers: any) -> list[any] {
    value: any = findHeader(headers, "authentication-results");
    out: list[any] = [];
    if not value {
        return out;
    }
    for clause in globalThis.String.prototype.split.call(value, CLAUSE) {
        end: int = globalThis.String.prototype.indexOf.call(clause, ";");
        id: any = clause if end < 0 else globalThis.String.prototype.slice.call(clause, 0, end);
        if lower(globalThis.String.prototype.trim.call(id)) == TRUSTED {
            out.append(clause);
        }
    }
    return out;
}

# A fail in any trusted clause wins; a pass needs every clause that names the method to agree.
def:priv header_result(clauses: list[any], m: str) -> any {
    regex = RESULT[m];
    passed = False;
    other = False;
    for clause in clauses {
        found: any = globalThis.RegExp.prototype.exec.call(regex, clause);
        if found {
            result = lower(found[1]);
            if result == "fail" {
                return "fail";
            }
            if result == "pass" {
                passed = True;
            } else {
                other = True;
            }
        }
    }
    return "pass" if passed and not other else None;
}

def:priv field(o: any, k: str) -> any {
    return globalThis.Reflect.get(globalThis.Object(o), k);
}

"""True when the receiving provider gave any verdict of its own, which then replaces the headers."""
def:priv provided(verdicts: any) -> bool {
    if not globalThis.Boolean(verdicts) {
        return False;
    }
    return bool(
        globalThis.Boolean(field(verdicts, "spf"))
            or globalThis.Boolean(field(verdicts, "dkim"))
            or globalThis.Boolean(field(verdicts, "dmarc"))
            or globalThis.Boolean(field(verdicts, "spam")),
    );
}

# `verdicts[name]?.toLowerCase()`.
def:priv verdict(verdicts: any, name: str) -> any {
    value = field(verdicts, name);
    return None if value is None or value is NULL else lower(value);
}

"""The receiving side's own DMARC verdict for a message, by the trust rules spam analysis uses."""
def readTrustedDmarcResult(headers: any = None, verdicts: any = None) -> any {
    if provided(verdicts) {
        result = verdict(verdicts, "dmarc");
        return result if result == "pass" or result == "fail" else None;
    }
    return header_result(trusted_clauses(headers), "dmarc");
}

"""
SPF, DKIM and DMARC results. Verdicts from the receiving provider (SES) win; otherwise only an
Authentication-Results clause written by Cloudflare is read. Self-hosted SMTP verifies SPF, DKIM
and DMARC itself (server/runtime/smtp-auth.ts) and passes the outcome in as verdicts.
"""
def analyzeAuthentication(headers: any = None, verdicts: any = None) -> list[any] {
    signals: list[any] = [];
    given = provided(verdicts);
    clauses: list[any] = [] if given else trusted_clauses(headers);
    for m in METHODS {
        result = verdict(verdicts, m) if given else header_result(clauses, m);
        signal = method_signal(m, result);
        if signal is not None {
            signals.append(signal);
        }
    }
    if given and verdict(verdicts, "spam") == "fail" {
        why = "The receiving mail provider classified this message as spam";
        score = SPAM_WEIGHTS.provider.spamVerdict;
        signals.append({"id": "provider_spam_verdict", "score": score, "reason": why});
    }
    return signals;
}
