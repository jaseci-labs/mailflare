glob:priv BYDAY: list[str] = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"],
          FREQ: dict[str, str] = {
              "daily": "FREQ=DAILY",
              "weekly": "FREQ=WEEKLY",
              "yearly": "FREQ=YEARLY",
          },
          WALL_CLOCK: dict[str, str] = {
              "hourCycle": "h23",
              "year": "numeric",
              "month": "2-digit",
              "day": "2-digit",
              "hour": "2-digit",
              "minute": "2-digit",
              "second": "2-digit",
          };

def:priv day_code(day: any) -> str {
    return BYDAY[day] if globalThis.Number.isInteger(day) and 0 <= day <= 6 else "undefined";
}

"""The wall-clock time of an instant in a zone, as an iCalendar local DATE-TIME."""
def:priv zoned(value: any, timeZone: str) -> str {
    parts = new(
        globalThis.Intl.DateTimeFormat, "en-CA", merged(WALL_CLOCK, {"timeZone": timeZone})
    ).formatToParts(value);
    f: dict[str, str] = {};
    for part in parts {
        f.setdefault(part["type"], part["value"]);
    }
    return "".join(
        [f.get(k, "00") for k in ["year", "month", "day"]]
            + ["T"]
            + [f.get(k, "00") for k in ["hour", "minute", "second"]],
    );
}

def:priv validTimeZone(value: any) -> any {
    if not value {
        return NULL;
    }
    try {
        new(globalThis.Intl.DateTimeFormat, "en", record({"timeZone": value}));
        return value;
    } except Exception {
        return NULL;
    }
}

def:priv dateProperty(name: str, value: any, timeZone: any) -> str {
    return f"{name};TZID={timeZone}:{zoned(value, timeZone)}"
        if timeZone
        else f"{name}:{formatIcsUtc(value)}";
}

"""
The app moves a monthly event anchored on the 29th-31st to the last day of shorter months, while a plain
BYMONTHDAY=31 skips them (RFC 5545 drops invalid dates), so those anchors list 28..anchor and keep the last.
"""
def:priv monthDayRule(day: any) -> str {
    if day < 29 {
        return f"BYMONTHDAY={globalThis.String(day)}";
    }
    listed = ",".join([str(28 + i) for i in range(globalThis.Math.trunc(day - 27))]);
    return f"BYMONTHDAY={listed};BYSETPOS=-1";
}

def:priv recurrenceRule(event: any) -> any {
    repeat = event["repeat"];
    if repeat == "none" {
        return NULL;
    }
    parts: list[str] = [];
    if repeat in FREQ {
        parts = [FREQ[repeat]];
    } elif repeat == "monthly" {
        parts = ["FREQ=MONTHLY"];
        (weekday, week) = (event["repeatWeekday"], event["repeatWeek"]);
        if not nil(weekday) and not nil(week) {
            parts.append(f"BYDAY={globalThis.String(week)}{day_code(weekday)}");
        } else {
            zone = validTimeZone(event["timeZone"]);
            starts = zoned(event["startsAt"], zone) if zone else formatIcsUtc(event["startsAt"]);
            parts.append(monthDayRule(event["repeatAnchorDay"] or globalThis.Number(starts[6:8])));
        }
    } else {
        days = parseCalendarRepeatDays(event["repeatDays"]);
        if not days {
            return NULL;
        }
        parts = ["FREQ=WEEKLY", "BYDAY=" + ",".join([BYDAY[day] for day in days])];
    }
    # A listed-days repeat steps day by day, so its interval is always 1 and never written.
    interval = event["repeatInterval"];
    if repeat != "weekdays" and globalThis.Number.isInteger(interval) and interval > 1 {
        parts.append(f"INTERVAL={interval}");
    }
    # repeatUntil is an exclusive bound in the app; RFC 5545 UNTIL is inclusive, so stop one second earlier.
    until = event["repeatUntil"];
    if until {
        parts.append(f"UNTIL={formatIcsUtc(new(globalThis.Date, until.getTime() - 1000))}");
    }
    return "RRULE:" + ";".join(parts);
}

"""
Each override is one edited occurrence (RECURRENCE-ID): it replaces the rule occurrence at `occurrenceMs`,
or adds an extra one when no rule occurrence has that start.
"""
def buildCalendarFeed(events: any, options: any, overrides: any = None) -> str {
    stamp = formatIcsUtc(either(options["now"], new(globalThis.Date)));
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Mailflare//Calendar//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        f"X-WR-CALNAME:{escapeIcsText(options['name'])}",
        "REFRESH-INTERVAL;VALUE=DURATION:PT1H",
        "X-PUBLISHED-TTL:PT1H",
    ];
    for event in events {
        rule = recurrenceRule(event);
        # Recurring events keep their local clock time across daylight saving changes only when they carry a zone.
        zone = validTimeZone(event["timeZone"]) if rule else NULL;
        head = ["BEGIN:VEVENT", f"UID:{event['id']}@mailflare", f"DTSTAMP:{stamp}"];
        summary = f"SUMMARY:{escapeIcsText(event['title'])}";
        excluded = parseExcludedOccurrences(event["excludedOccurrences"]);
        lines += head + [
            dateProperty("DTSTART", event["startsAt"], zone),
            dateProperty("DTEND", event["endsAt"], zone),
            summary,
        ];
        if event["description"] {
            lines.append(f"DESCRIPTION:{escapeIcsText(event['description'])}");
        }
        if event["location"] {
            lines.append(f"LOCATION:{escapeIcsText(event['location'])}");
        }
        if rule {
            lines.append(rule);
            lines += [dateProperty("EXDATE", new(globalThis.Date, ms), zone) for ms in excluded];
        }
        if event["responseStatus"] == "tentative" {
            lines.append("STATUS:TENTATIVE");
        }
        if event["updatedAt"] {
            lines.append(f"LAST-MODIFIED:{formatIcsUtc(event['updatedAt'])}");
        }
        lines.append("END:VEVENT");
        # PUBLISH stays VALARM-free and attendee-free: overrides carry only the replacement time.
        for moved in (either(overrides.get(event["id"]), []) if overrides else []) {
            if moved["occurrenceMs"] in excluded {
                continue;
            }
            # The same TZID form as the master's DTSTART, so the RECURRENCE-ID pairs with its rule occurrence.
            lines += head + [
                dateProperty("RECURRENCE-ID", new(globalThis.Date, moved["occurrenceMs"]), zone),
                dateProperty("DTSTART", moved["startsAt"], zone),
                dateProperty("DTEND", moved["endsAt"], zone),
                summary,
                "END:VEVENT",
            ];
        }
    }
    lines.append("END:VCALENDAR");
    return joinIcsLines(lines);
}

# What a TypeScript caller names: one edited occurrence, {occurrenceMs, startsAt, endsAt}.
type FeedOccurrenceOverride = any;
