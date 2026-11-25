def:priv at_hour(date: any, hours: int) -> any {
    fields = new(globalThis.Date, date);
    fields.setUTCHours(hours, 0, 0, 0);
    return dateFromZonedFields(fields, getUserTimeZone());
}

def getScheduleSendOptions(now: any = None) -> any {
    now = new(globalThis.Date) if now is None else now;
    later = new(globalThis.Date, now.getTime() + 3 * 60 * 60 * 1000);
    today = zonedDateFields(now, getUserTimeZone());
    (tomorrow, monday) = (new(globalThis.Date, today), new(globalThis.Date, today));
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    monday.setUTCDate(monday.getUTCDate() + ((8 - monday.getUTCDay()) % 7 or 7));
    (a, b) = (zonedDateFields(later, getUserTimeZone()).toISOString(), today.toISOString());
    soon = "schedule.laterToday" if a[:10] == b[:10] else "schedule.in3Hours";
    return [
        {"labelKey": soon, "value": later},
        {"labelKey": "schedule.tomorrowMorning", "value": at_hour(tomorrow, 8)},
        {"labelKey": "schedule.mondayMorning", "value": at_hour(monday, 8)},
    ];
}

def formatScheduledSend(value: any) -> str {
    parts = {"weekday": "short", "month": "short", "day": "numeric", "hour": "numeric"};
    return formatUserDate(value, record({**parts, "minute": "2-digit"}));
}

def formatDateTimeLocal(value: any) -> str {
    return formatUserDateTimeLocal(value);
}

def parseDateTimeLocal(value: any) -> any {
    return parseUserDateTimeLocal(value);
}

def isPastSchedule(value: any, now: any = None) -> bool {
    t = (new(globalThis.Date) if now is None else now).getTime();
    return value.getTime() < t - t % 60000;
}
