# Offsets the event editor offers, in minutes before the start.
glob REMINDER_MINUTE_OPTIONS: list[int] = [0, 5, 10, 15, 30, 60, 120, 1440, 2880, 10080];

glob MAX_REMINDER_MINUTES: int = 10080;

# The reminder cron period. An "at time of event" reminder has a zero-width window, so it also fires for starts
# up to this long ago, but only for events that existed (were last saved) before that start.
glob REMINDER_GRACE_MS: int = 5 * 60000;

"""Reminder offset from untrusted input: a whole number of minutes in range, otherwise no reminder."""
def normalizeReminderMinutes(value: any = None) -> any {
    return value
        if globalThis.Number.isInteger(value) and 0 <= value <= MAX_REMINDER_MINUTES
        else NULL;
}

"""Push body: when the occurrence starts in the event's zone, then the place if it has one."""
def formatReminderBody(startsAt: any, timeZone: any, location: any) -> str {
    time = "";
    try {
        time = new(
            globalThis.Intl.DateTimeFormat,
            "en-US",
            record({
                "weekday": "short",
                "month": "short",
                "day": "numeric",
                "hour": "numeric",
                "minute": "2-digit",
                "timeZone": timeZone,
            }),
        ).format(startsAt);
    } except Exception {
        time = startsAt.toISOString();
    }
    place = location.trim();
    return f"{time} · {place}" if place else time;
}

"""Occurrences of `event` whose reminder is due at `now`, newer than `lastReminded` (ms), oldest first."""
def dueReminderOccurrences(
    event: any, now: any, lastReminded: int, limit: any = None, overrides: any = None
) -> list[any] {
    current = now.getTime();
    lead = either(event["reminderMinutes"], 0) * 60000;
    grace = REMINDER_GRACE_MS if lead == 0 else 0;
    saved = event["updatedAt"].getTime();
    due: list[any] = [];
    for occurrence in expandToolEvents(
        [event],
        new(globalThis.Date, current - grace),
        new(globalThis.Date, current + lead + 1),
        500,
        None if nil(overrides) else new(globalThis.Map, [[event["id"], overrides]]),
    ) {
        starts = new(globalThis.Date, occurrence["startsAt"]);
        start = starts.getTime();
        # An occurrence already under way only counts if the event was not created or edited after it began.
        if start <= current and saved > start {
            continue;
        }
        if start + grace > current and start - lead <= current and start > lastReminded {
            due.append(merged(occurrence, {"start": starts}));
        }
    }
    return due if limit is None else due[:limit];
}
