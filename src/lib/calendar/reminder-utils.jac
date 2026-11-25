# Offsets the event editor offers, in minutes before the start.
glob REMINDER_MINUTE_OPTIONS: list[int] = [0, 5, 10, 15, 30, 60, 120, 1440, 2880, 10080],
     MAX_REMINDER_MINUTES: int = 10080,
     # The reminder cron period. An "at time of event" reminder has a zero-width window, so it also
     # fires for starts up to this long ago, but only for events last saved before that start.
     REMINDER_GRACE_MS: int = 5 * 60000;

glob:priv BODY: any = {"weekday": "short", "month": "short", "day": "numeric", "hour": "numeric"};

"""Reminder offset from untrusted input: a whole number of minutes in range, otherwise no reminder."""
def normalizeReminderMinutes(value: any = None) -> any {
    return value if whole(value, 0, MAX_REMINDER_MINUTES) else NULL;
}

"""Push body: when the occurrence starts in the event's zone, then the place if it has one."""
def formatReminderBody(startsAt: any, timeZone: any, location: any) -> str {
    try {
        options = merged(BODY, {"minute": "2-digit", "timeZone": timeZone});
        time = new(globalThis.Intl.DateTimeFormat, "en-US", options).format(startsAt);
    } except Exception {
        time = startsAt.toISOString();
    }
    return f"{time} · {location.trim()}" if location.trim() else time;
}

"""Occurrences of `event` whose reminder is due at `now`, newer than `lastReminded` (ms), oldest first."""
def dueReminderOccurrences(event: any, now: any, last: int, n: any = None, ov: any = None) -> any {
    (t, lead) = (now.getTime(), either(event["reminderMinutes"], 0) * 60000);
    (grace, saved) = (REMINDER_GRACE_MS if lead == 0 else 0, event["updatedAt"].getTime());
    window = [new(globalThis.Date, t - grace), new(globalThis.Date, t + lead + 1)];
    ov = None if nil(ov) else new(globalThis.Map, [[event["id"], ov]]);
    due: any = [];
    for o in expandToolEvents([event], window[0], window[1], 500, ov) {
        (start, s) = (new(globalThis.Date, o["startsAt"]), globalThis.Date.parse(o["startsAt"]));
        # An occurrence already under way only counts if the event was not created or edited after it began.
        if not (s <= t and saved > s) and s + grace > t and s - lead <= t and s > last {
            due.append(merged(o, {"start": start}));
        }
    }
    return due.slice(0, n);
}
