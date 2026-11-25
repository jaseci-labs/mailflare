""""Today, 8:00 AM", "Tomorrow, 8:00 AM", "Friday, 8:00 AM" within a week, otherwise the date."""
def formatScheduledSendTime(value: any, t: any, now: any = None) -> str {
    (date, zone) = (new(globalThis.Date, value), getUserTimeZone());
    now = new(globalThis.Date) if now is None else now;
    (a, b) = (zonedDateFields(date, zone), zonedDateFields(now, zone));
    days = globalThis.Math.round(
        (a.setUTCHours(0, 0, 0, 0) - b.setUTCHours(0, 0, 0, 0)) / 86400000
    );
    hm = {"hour": "numeric", "minute": "2-digit"};
    if days == 0 or days == 1 {
        key = "schedule.todayAt" if days == 0 else "schedule.tomorrowAt";
        return t(key, record({"time": formatUserDate(date, record(hm))}));
    }
    year: dict[str, str] = {} if a.getUTCFullYear() == b.getUTCFullYear() else {"year": "numeric"};
    opts = {"weekday": "long"} if 2 <= days <= 7 else {"month": "short", "day": "numeric", **year};
    return formatUserDate(date, record({**opts, **hm}));
}
