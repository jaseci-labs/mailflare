import from "drizzle-orm" { and as all_of, desc, eq, gte, sql }

# Types the TypeScript callers name.
type TlsSeriesDay = dict[str, any];
type TlsStats = dict[str, any];

"""A drizzle `sql` fragment: each `?` of the template is the next value."""
def:priv sqlf(template: str, *values: any) -> any {
    return sql(template.split("?"), *values);
}

glob:priv LIMIT: int = 100,
          DAY_MS: int = 86400000,
          stats: any = tlsDailyStats,
          reports: any = deliverabilityReports,
          success: any = sqlf("coalesce(sum(?), 0)", stats.successCount),
          failure: any = sqlf("coalesce(sum(?), 0)", stats.failureCount),
          sessions: any = sqlf("sum(?) + sum(?)", stats.successCount, stats.failureCount);

def:priv is_day(date: any) -> str {
    return date.toISOString().slice(0, 10);
}

"""Daily totals, per-reporter, per-policy and per-failure-type tables and the latest TLS-RPT reports for one domain. Only verified reporters write rows, so nothing is filtered by trust here."""
async def getTlsStats(env: any, domainId: str, options: any) -> dict[str, any] {
    db = getDb(env);
    now = at(options, "now") or new(globalThis.Date);
    days: int = options["days"];
    start: int = globalThis.Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())
        - (days - 1) * DAY_MS;
    from_date = new(globalThis.Date, start);
    in_range = all_of(eq(stats.domainId, domainId), gte(stats.day, is_day(from_date)));
    of_domain = all_of(eq(reports.domainId, domainId), eq(reports.kind, "tlsrpt"));
    found = await globalThis.Promise.all([
        db.select({"day": stats.day, "success": success, "failure": failure}).from(stats).where(
            in_range
        ).groupBy(stats.day),
        db.select({"reporterOrg": stats.reporterOrg, "success": success, "failure": failure}).from(
            stats
        ).where(in_range).groupBy(stats.reporterOrg).orderBy(desc(sessions)).limit(LIMIT),
        db.select({
            "policyType": stats.policyType,
            "mxHost": stats.mxHost,
            "success": success,
            "failure": failure,
        }).from(stats).where(in_range).groupBy(stats.policyType, stats.mxHost).orderBy(
            desc(sessions)
        ).limit(LIMIT),
        db.select({"resultType": stats.resultType, "failure": failure}).from(stats).where(
            all_of(in_range, sqlf("? > 0", stats.failureCount))
        ).groupBy(stats.resultType).orderBy(desc(sqlf("sum(?)", stats.failureCount))).limit(LIMIT),
        db.select({"reports": sqlf("count(*)")}).from(reports).where(
            all_of(of_domain, eq(reports.status, "unverified"), gte(reports.receivedAt, from_date))
        ),
        db.select().from(reports).where(of_domain).orderBy(desc(reports.receivedAt)).limit(10),
    ]);
    (daily, reporter_rows, policy_rows, type_rows, unverified, recent) = found;
    number = globalThis.Number;
    by_day = {row.day: row for row in daily};
    series: list[any] = [];
    for index in range(days) {
        day = is_day(new(globalThis.Date, start + index * DAY_MS));
        row = by_day.get(day);
        series.append({
            "day": day,
            "success": number(at(row, "success", 0) if row else 0),
            "failure": number(at(row, "failure", 0) if row else 0),
        });
    }
    return {
        "days": days,
        "series": series,
        "reporters": [
            {
                "reporterOrg": row.reporterOrg,
                "success": number(row.success),
                "failure": number(row.failure),
            }
            for row in reporter_rows
        ],
        "policies": [
            {
                "policyType": row.policyType,
                "mxHost": row.mxHost,
                "success": number(row.success),
                "failure": number(row.failure),
            }
            for row in policy_rows
        ],
        "failureTypes": [
            {"resultType": row.resultType, "failure": number(row.failure)}
            for row in type_rows
        ],
        "unverifiedReports": number(at(unverified[0], "reports", 0) if unverified.length else 0),
        "recentReports": [
            {
                "id": row.id,
                "reporterOrg": row.reporterOrg,
                "dateBegin": row.dateBegin.toISOString() if row.dateBegin else NULL,
                "status": row.status,
                "error": row.error,
                "messageCount": row.messageCount,
                "verifiedReporter": row.verifiedReporter,
                "receivedAt": row.receivedAt.toISOString(),
            }
            for row in recent
        ],
    };
}
