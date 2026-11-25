"""
Pure alert rules for the daily deliverability job. Spoofing and regression are evaluated on the aggregates of ONE
verified reporter at a time (see `mergeReporterAlerts`), so a reporter can only influence its own numbers.
`no_reports` is domain-wide: any verified reporter's report resets it. That is a known, accepted limitation
(docs/dmarc-reports.md): an attacker with their own DMARC-passing domain can keep it from firing.
"""

glob ALERT_RULES: any = globalThis.Object.freeze(
    record({
        "spoofingMinFailed": 10,
        "spoofTopSources": 5,
        "regressionMinHistory": 50,
        "regressionMinPass": 0.9,
        "regressionMaxPass": 0.5,
        "regressionMinToday": 10,
        "noReportsEnabledDays": 3,
        "noReportsSilentDays": 7,
        "noReportsRepeatDays": 7,
    }),
);

# Types the TypeScript callers name.
type SourceTotals = dict[str, any];
type AlertKind = str;
type AlertSource = dict[str, any];
type AlertDetail = dict[str, any];
type EvaluatedAlert = dict[str, any];

glob:priv DAY = 86400000;

"""The busiest offenders: most failures first, then by address."""
def:priv top(sources: list[any]) -> list[any] {
    ordered = globalThis.Array.prototype.sort.call(
        sources,
        lambda (a: any, b: any) -> any {
            (b["failed"] - a["failed"]) or a["sourceIp"].localeCompare(b["sourceIp"])
        },
    );
    return ordered[:ALERT_RULES.spoofTopSources];
}

def:priv offender(row: any) -> dict[str, any] {
    return {
        "sourceIp": row["sourceIp"],
        "messages": row["messages"],
        "failed": row["messages"] - row["passMessages"],
    };
}

"""Spoofing and regression from one reporter's totals."""
def evaluateSourceAlerts(input: any) -> list[any] {
    prior = {row["sourceIp"]: row for row in input["prior30"]};
    spoofing = [
        offender(row)
        for row in input["yesterday"]
        if row["messages"] - row["passMessages"] >= ALERT_RULES.spoofingMinFailed
            and (prior[row["sourceIp"]]["passMessages"] if row["sourceIp"] in prior else 0) == 0
    ];
    spoofed = [row["sourceIp"] for row in spoofing];

    def regressed_from(row: any) -> bool {
        before = prior.get(row["sourceIp"]);
        return row["sourceIp"] not in spoofed
            and bool(before)
            and before["messages"] >= ALERT_RULES.regressionMinHistory
            and before["passMessages"] / before["messages"] >= ALERT_RULES.regressionMinPass
            and row["messages"] >= ALERT_RULES.regressionMinToday
            and row["passMessages"] / row["messages"] < ALERT_RULES.regressionMaxPass;
    }
    regressed = [offender(row) for row in input["yesterday"] if regressed_from(row)];
    return [
        {"kind": kind, "detail": {"sources": top(list(found)), "total": len(found)}}
        for (kind, found) in [("spoofing", spoofing), ("auth_regression", regressed)]
        if found
    ];
}

def evaluateNoReports(input: any) -> any {
    now = input["now"].getTime();
    (enabled, last, alerted) = (
        input["reportsEnabledAt"],
        input["lastReportAt"],
        input["lastNoReportsAlertAt"],
    );
    enabled_long_enough = enabled is not NULL
        and now - enabled.getTime() >= ALERT_RULES.noReportsEnabledDays * DAY;
    silent = last is NULL or now - last.getTime() >= ALERT_RULES.noReportsSilentDays * DAY;
    throttled = alerted is not NULL
        and now - alerted.getTime() < ALERT_RULES.noReportsRepeatDays * DAY;
    if not enabled_long_enough or not silent or throttled {
        return NULL;
    }
    return {
        "kind": "no_reports",
        "detail": {"lastReportAt": NULL if nil(last) else last.toISOString()},
    };
}

"""All three rules on one set of totals (one reporter's, or the whole domain's in tests)."""
def evaluateAlerts(input: any) -> list[any] {
    no_reports = evaluateNoReports(input);
    return evaluateSourceAlerts(input) + ([no_reports] if no_reports else []);
}

"""One alert per kind for the domain: each reporter's offenders, tagged with the reporter, the busiest five listed."""
def mergeReporterAlerts(parts: any) -> list[any] {
    result: list[any] = [];
    for kind in ["spoofing", "auth_regression"] {
        sources: list[any] = [];
        total = 0;
        for part in parts {
            for alert in part["alerts"] {
                if alert["kind"] == kind {
                    if owns(alert["detail"], "sources") {
                        total += alert["detail"]["total"];
                        sources += [
                            merged(source, {"reporter": part["reporter"]})
                            for source in alert["detail"]["sources"]
                        ];
                    }
                    break;
                }
            }
        }
        if total > 0 {
            result.append({"kind": kind, "detail": {"sources": top(sources), "total": total}});
        }
    }
    return result;
}
