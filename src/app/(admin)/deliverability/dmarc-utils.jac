# A report still `processing` after an hour was most likely killed by the platform's CPU limit.
glob:priv STUCK_AFTER_MS = 60 * 60 * 1000,
          MATH: any = globalThis.Math,
          RESULTS = ["pass", "failDelivered", "quarantined", "rejected"],
          SETTLED = ["ok", "rejected", "unverified", "over_budget"],
          ERRORS = """ADDRESS_TAKEN RECEIVING_REQUIRED MULTIPLE_DMARC_RECORDS DNS_FAILED
              ROUTING_FAILED MIGRATION_REQUIRED DMARC_CHANGED TLS_RPT_ON""".split();

glob percent: any = lambda (p: any, t: any) -> any { MATH.round(p / t * 100) if t > 0 else 0 },
     dayTotal: any = lambda (day: any) -> any { sum(globalThis.Number(day[k]) for k in RESULTS) },
     chartMax: any = lambda (series: any) -> any { MATH.max(0, *[dayTotal(d) for d in series]) },
     errorKey: any = lambda (c: any) -> any { f"dmarc.error.{c}" if c in ERRORS else NULL };

# Bar height as a share of the tallest bar (at least 2%, so a small day shows) and each result's share.
def segmentPercents(day: any, tallest: any) -> any {
    total = num_or(dayTotal(day), 0);
    height = MATH.max(2, MATH.round(total / tallest * 100)) if total else 0;
    return merged({"height": height}, {k: day[k] / total * 100 if total else 0 for k in RESULTS});
}

def reportStatusKey(status: str, receivedAt: any, now: any = None) -> str {
    if status == "processing" {
        age = (globalThis.Date.now() if now is None else now) - globalThis.Date.parse(receivedAt);
        return "stuck" if age > STUCK_AFTER_MS else "processing";
    }
    return status if status in SETTLED else "failed";
}
