# Alert rules for the daily job. Spoofing and regression read ONE verified reporter's aggregates
# at a time (`mergeReporterAlerts`), so a reporter only moves its own numbers. `no_reports` is
# domain-wide: any verified report resets it, so an attacker with a DMARC-passing domain can keep
# it from firing (a known, accepted limitation: docs/dmarc-reports.md).
glob ALERT_RULES: any = globalThis.Object.freeze(globalThis.JSON.parse("""{"spoofingMinFailed": 10,
    "spoofTopSources": 5, "regressionMinHistory": 50, "regressionMinPass": 0.9,
    "regressionMaxPass": 0.5, "regressionMinToday": 10, "noReportsEnabledDays": 3,
    "noReportsSilentDays": 7, "noReportsRepeatDays": 7}"""));

type SourceTotals = any;

type AlertKind = str;

type EvaluatedAlert = any;

glob:priv R: any = ALERT_RULES,
          DAY: int = 86400000;

"""The busiest offenders: most failures first, then by address."""
def:priv top(xs: any) -> any {
    order = lambda (a: any, b: any) -> any {
        (b["failed"] - a["failed"]) or a["sourceIp"].localeCompare(b["sourceIp"])
    };
    return js_sort(xs, order).slice(0, R.spoofTopSources);
}

def:priv offender(r: any) -> any {
    (ip, n) = (r["sourceIp"], r["messages"]);
    return {"sourceIp": ip, "messages": n, "failed": n - r["passMessages"]};
}

"""Spoofing and regression from one reporter's totals."""
def evaluateSourceAlerts(input: any) -> list[any] {
    (rows, prior) = (input["yesterday"], {row["sourceIp"]: row for row in input["prior30"]});
    ok = lambda (r: any) -> bool { at(prior.get(r["sourceIp"]), "passMessages", 0) == 0 };
    bad = [r for r in rows if r["messages"] - r["passMessages"] >= R.spoofingMinFailed and ok(r)];
    (spoofing, spoofed) = ([offender(r) for r in bad], [r["sourceIp"] for r in bad]);

    def regressed(r: any) -> bool {
        b = prior.get(r["sourceIp"]);
        was = bool(b) and b["messages"] >= R.regressionMinHistory;
        was = was and b["passMessages"] / b["messages"] >= R.regressionMinPass;
        now = r["messages"] >= R.regressionMinToday;
        now = now and r["passMessages"] / r["messages"] < R.regressionMaxPass;
        return r["sourceIp"] not in spoofed and was and now;
    }
    regs = [offender(r) for r in rows if regressed(r)];
    found = [("spoofing", spoofing), ("auth_regression", regs)];
    return [{"kind": k, "detail": {"sources": top(x), "total": len(x)}} for (k, x) in found if x];
}

def evaluateNoReports(input: any) -> any {
    (now, last) = (input["now"].getTime(), input["lastReportAt"]);
    (enabled, alerted) = (input["reportsEnabledAt"], input["lastNoReportsAlertAt"]);
    old = enabled is not NULL and now - enabled.getTime() >= R.noReportsEnabledDays * DAY;
    silent = last is NULL or now - last.getTime() >= R.noReportsSilentDays * DAY;
    throttled = alerted is not NULL and now - alerted.getTime() < R.noReportsRepeatDays * DAY;
    if not old or not silent or throttled {
        return NULL;
    }
    detail = {"lastReportAt": NULL if nil(last) else last.toISOString()};
    return {"kind": "no_reports", "detail": detail};
}

"""All three rules on one set of totals (one reporter's, or the whole domain's in tests)."""
def evaluateAlerts(input: any) -> list[any] {
    no_reports = evaluateNoReports(input);
    return evaluateSourceAlerts(input) + ([no_reports] if no_reports else []);
}

"""One alert per kind for the domain: each reporter's offenders, tagged, the busiest five listed."""
def mergeReporterAlerts(parts: any) -> list[any] {
    result: list[any] = [];
    for k in ["spoofing", "auth_regression"] {
        found = [(p["reporter"], first([a for a in p["alerts"] if a["kind"] == k])) for p in parts];
        found = [(r, a["detail"]) for (r, a) in found if a and owns(a["detail"], "sources")];
        total = sum([d["total"] for (_, d) in found]);
        sources = [merged(s, {"reporter": r}) for (r, d) in found for s in d["sources"]];
        if total > 0 {
            result.append({"kind": k, "detail": {"sources": top(sources), "total": total}});
        }
    }
    return result;
}
