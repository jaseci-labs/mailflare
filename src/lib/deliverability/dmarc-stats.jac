import from "drizzle-orm" { and as all_of, desc, eq, gte, sql }

# Types the TypeScript callers name.
type DmarcDays = int;
type DmarcSeriesDay = dict[str, any];
type DmarcSource = dict[str, any];
type DmarcReporter = dict[str, any];
type DmarcRecentReport = dict[str, any];
type DmarcStats = dict[str, any];

"""A drizzle `sql` fragment: each `?` of the template is the next value."""
def:priv sqlf(template: str, *values: any) -> any {
    return sql(template.split("?"), *values);
}

glob:priv SOURCE_LIMIT: int = 100,
          REPORTER_LIMIT: int = 100,
          DAY_MS: int = 86400000,
          stats: any = dmarcDailyStats,
          reports: any = deliverabilityReports,
          # DMARC passes when either identifier aligned. Plain boolean expressions keep this portable across the three dialects.
          passed: any = sqlf("(? or ?)", stats.dkimAligned, stats.spfAligned),
          volume: any = sqlf("sum(?)", stats.messageCount);

"""The messages of the rows that meet `condition`."""
def:priv total(condition: any) -> any {
    return sqlf("coalesce(sum(case when ? then ? else 0 end), 0)", condition, stats.messageCount);
}

def:priv failed_with(disposition: str) -> any {
    return total(sqlf(f"not ? and ? = '{disposition}'", passed, stats.disposition));
}

def:priv is_day(date: any) -> str {
    return date.toISOString().slice(0, 10);
}

def normalizeDays(value: any = None) -> int {
    days = globalThis.Number(value);
    return days if days in [7, 90] else 30;
}

"""
Daily series, per-source and per-reporter tables and the latest reports for one domain over the last 7, 30 or 90
days. Aggregates only ever come from verified reporters, so there is nothing to filter by trust here.
"""
async def getDmarcStats(env: any, domainId: str, options: any) -> dict[str, any] {
    db = getDb(env);
    now = at(options, "now") or new(globalThis.Date);
    days: int = options["days"];
    start: int = globalThis.Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
        - (days - 1) * DAY_MS;
    from_date = new(globalThis.Date, start);
    in_range = all_of(eq(stats.domainId, domainId), gte(stats.day, is_day(from_date)));
    of_domain = [eq(reports.domainId, domainId), eq(reports.kind, "dmarc")];
    found = await globalThis.Promise.all([
        db.select({
            "day": stats.day,
            "pass": total(passed),
            "failDelivered": failed_with("none"),
            "quarantined": failed_with("quarantine"),
            "rejected": failed_with("reject"),
        }).from(stats).where(in_range).groupBy(stats.day),
        db.select({
            "sourceIp": stats.sourceIp,
            "sourceHost": sqlf("max(?)", stats.sourceHost),
            "messages": volume,
            "passMessages": total(passed),
            "dkimMessages": total(sqlf("?", stats.dkimAligned)),
            "spfMessages": total(sqlf("?", stats.spfAligned)),
            "worst": sqlf(
                "max(case ? when 'reject' then 2 when 'quarantine' then 1 else 0 end)",
                stats.disposition,
            ),
            "reporters": sqlf("count(distinct ?)", stats.reporterOrg),
        }).from(stats).where(in_range).groupBy(stats.sourceIp).orderBy(desc(volume)).limit(
            SOURCE_LIMIT
        ),
        db.select({
            "reporterOrg": stats.reporterOrg,
            "messages": volume,
            "passMessages": total(passed),
        }).from(stats).where(in_range).groupBy(stats.reporterOrg).orderBy(desc(volume)).limit(
            REPORTER_LIMIT
        ),
        # Verified reports are grouped by the verified sender, the same name the aggregate rows carry.
        db.select({"reporterOrg": reports.senderDomain, "reports": sqlf("count(*)")}).from(
            reports
        ).where(
            all_of(*of_domain, eq(reports.status, "ok"), gte(reports.dateBegin, from_date))
        ).groupBy(reports.senderDomain).limit(REPORTER_LIMIT * 2),
        db.select({"reports": sqlf("count(*)")}).from(reports).where(
            all_of(*of_domain, eq(reports.status, "unverified"), gte(reports.receivedAt, from_date))
        ),
        db.select().from(reports).where(all_of(*of_domain)).orderBy(desc(reports.receivedAt)).limit(10),
    ]);
    (daily, source_rows, reporter_rows, report_counts, unverified, recent) = found;
    number = globalThis.Number;
    by_day = {row.day: row for row in daily};
    series: list[any] = [];
    for index in range(days) {
        day = is_day(new(globalThis.Date, start + index * DAY_MS));
        row = by_day.get(day);
        series.append({
            "day": day,
            **{
                name: number(at(row, name, 0) if row else 0)
                for name in ["pass", "failDelivered", "quarantined", "rejected"]
            },
        });
    }
    reports_by = {row.reporterOrg: number(row.reports) for row in report_counts};
    return {
        "days": days,
        "series": series,
        "sources": [
            {
                "sourceIp": row.sourceIp,
                "sourceHost": row.sourceHost,
                "messages": number(row.messages),
                "passMessages": number(row.passMessages),
                "dkimMessages": number(row.dkimMessages),
                "spfMessages": number(row.spfMessages),
                "worstDisposition": "reject"
                    if number(row.worst) >= 2
                    else "quarantine" if number(row.worst) == 1 else "none",
                "reporters": number(row.reporters),
            }
            for row in source_rows
        ],
        "unverifiedReports": number(at(unverified[0], "reports", 0) if unverified.length else 0),
        "reporters": [
            {
                "reporterOrg": row.reporterOrg,
                "reports": reports_by.get(row.reporterOrg, 0),
                "messages": number(row.messages),
                "passMessages": number(row.passMessages),
            }
            for row in reporter_rows
        ],
        "recentReports": [recent_report(row) for row in recent],
    };
}

"""A stored report as the dashboards list it."""
def:priv recent_report(row: any) -> dict[str, any] {
    return {
        "id": row.id,
        "reporterOrg": row.reporterOrg,
        "dateBegin": row.dateBegin.toISOString() if row.dateBegin else NULL,
        "status": row.status,
        "error": row.error,
        "messageCount": row.messageCount,
        "verifiedReporter": row.verifiedReporter,
        "receivedAt": row.receivedAt.toISOString(),
    };
}
