glob:priv BYDAY: list[str] = "SU MO TU WE TH FR SA".split(),
          FREQ: any = {k: f"FREQ={k.upper()}" for k in ["daily", "weekly", "yearly"]},
          HEAD: str = """BEGIN:VCALENDAR VERSION:2.0 PRODID:-//Mailflare//Calendar//EN
              CALSCALE:GREGORIAN METHOD:PUBLISH""",
          TEXTS: list[str] = ["description", "location"],
          D: any = globalThis.Date,
          TTL: list[str] = ["REFRESH-INTERVAL;VALUE=DURATION:PT1H", "X-PUBLISHED-TTL:PT1H"],
          LOCAL_OPTIONS: any = {
              "hourCycle": "h23",
              "year": "numeric",
              "month": "2-digit",
              "day": "2-digit",
              "hour": "2-digit",
              "minute": "2-digit",
              "second": "2-digit",
          },
          # Formatters by zone, and whether a zone is valid: the same answer every time, so kept
          # (at most 64 of each, emptied when full) instead of constructed per date.
          LOCAL: dict[any, any] = {},
          VALID: dict[any, any] = {};

# The wall-clock time of an instant in a zone, as an iCalendar local DATE-TIME (each field the
# first part of its type, "00" when there is none).
def:priv zoned(value: any, tz: any) -> str {
    dtf = LOCAL.get(tz);
    if dtf is None {
        dtf = new(globalThis.Intl.DateTimeFormat, "en-CA", merged(LOCAL_OPTIONS, {"timeZone": tz}));
        if len(LOCAL) >= 64 {
            LOCAL.clear();
        }
        LOCAL[tz] = dtf;
    }
    year: any = None;
    month: any = None;
    day: any = None;
    hour: any = None;
    minute: any = None;
    second: any = None;
    for part in globalThis.Intl.DateTimeFormat.prototype.formatToParts.call(dtf, value) {
        kind = globalThis.Reflect.get(part, "type");
        if kind == "year" and year is None {
            year = globalThis.Reflect.get(part, "value");
        } elif kind == "month" and month is None {
            month = globalThis.Reflect.get(part, "value");
        } elif kind == "day" and day is None {
            day = globalThis.Reflect.get(part, "value");
        } elif kind == "hour" and hour is None {
            hour = globalThis.Reflect.get(part, "value");
        } elif kind == "minute" and minute is None {
            minute = globalThis.Reflect.get(part, "value");
        } elif kind == "second" and second is None {
            second = globalThis.Reflect.get(part, "value");
        }
    }
    return globalThis.String.prototype.concat.call(
        "",
        either(year, "00"),
        either(month, "00"),
        either(day, "00"),
        "T",
        either(hour, "00"),
        either(minute, "00"),
        either(second, "00"),
    );
}

def:priv valid_zone(value: any) -> any {
    if not value {
        return NULL;
    }
    ok = VALID.get(value) if isinstance(value, str) else None;
    if ok is None {
        try {
            new(globalThis.Intl.DateTimeFormat, "en", record({"timeZone": value}));
            ok = True;
        } except Exception {
            ok = False;
        }
        if isinstance(value, str) {
            if len(VALID) >= 64 {
                VALID.clear();
            }
            VALID[value] = ok;
        }
    }
    return value if ok else NULL;
}

def:priv prop(name: str, value: any, tz: any) -> str {
    return f"{name};TZID={tz}:{zoned(value, tz)}" if tz else f"{name}:{formatIcsUtc(value)}";
}

# The app moves a monthly event anchored on the 29th-31st to the last day of shorter months, while a
# plain BYMONTHDAY=31 skips them (RFC 5545 drops invalid dates), so those anchors list 28..anchor and
# keep the last.
def:priv month_day_rule(day: any) -> str {
    listed = ",".join([str(d) for d in range(28, globalThis.Math.trunc(day) + 1)]) + ";BYSETPOS=-1";
    return f"BYMONTHDAY={globalThis.String(day) if day < 29 else listed}";
}

def:priv rrule(ev: any) -> any {
    rep = ev["repeat"];
    n = ev["repeatInterval"];
    until = ev["repeatUntil"];
    if rep == "none" {
        return NULL;
    } elif rep in FREQ {
        parts = [FREQ[rep]];
    } elif rep == "monthly" and not nil(ev["repeatWeekday"]) and not nil(ev["repeatWeek"]) {
        code = globalThis.String(globalThis.Reflect.get(BYDAY, ev["repeatWeekday"]));
        parts = ["FREQ=MONTHLY", f"BYDAY={globalThis.String(ev['repeatWeek'])}{code}"];
    } elif rep == "monthly" {
        zone = valid_zone(ev["timeZone"]);
        starts = zoned(ev["startsAt"], zone) if zone else formatIcsUtc(ev["startsAt"]);
        day = ev["repeatAnchorDay"] or globalThis.Number(starts[6:8]);
        parts = ["FREQ=MONTHLY", month_day_rule(day)];
    } else {
        days = parseCalendarRepeatDays(ev["repeatDays"]);
        if not days {
            return NULL;
        }
        parts = ["FREQ=WEEKLY", "BYDAY=" + ",".join([BYDAY[day] for day in days])];
    }
    # A listed-days repeat steps day by day, so its interval is always 1 and never written.
    stepped = rep != "weekdays" and globalThis.Number.isInteger(n) and n > 1;
    parts += [f"INTERVAL={n}"] if stepped else [];
    # repeatUntil is exclusive in the app; RFC 5545 UNTIL is inclusive, so stop one second earlier.
    parts += [f"UNTIL={formatIcsUtc(new(D, until.getTime() - 1000))}"] if until else [];
    return "RRULE:" + ";".join(parts);
}

# Each override is one edited occurrence (RECURRENCE-ID): it replaces the rule occurrence at
# `occurrenceMs`, or adds an extra one when no rule occurrence has that start.
def buildCalendarFeed(events: any, options: any, overrides: any = None) -> str {
    stamp = formatIcsUtc(either(options["now"], new(globalThis.Date)));
    lines = HEAD.split() + [f"X-WR-CALNAME:{escapeIcsText(options['name'])}"] + TTL;
    for ev in events {
        rule = rrule(ev);
        # Recurring events keep their local clock time across daylight saving changes only with a zone.
        zone = valid_zone(ev["timeZone"]) if rule else NULL;
        head = ["BEGIN:VEVENT", f"UID:{ev['id']}@mailflare", f"DTSTAMP:{stamp}"];
        summary = f"SUMMARY:{escapeIcsText(ev['title'])}";
        excluded = parseExcludedOccurrences(ev["excludedOccurrences"]);
        dates = [prop("DTSTART", ev["startsAt"], zone), prop("DTEND", ev["endsAt"], zone)];
        lines += head + dates + [summary];
        lines += [f"{k.upper()}:{escapeIcsText(ev[k])}" for k in TEXTS if ev[k]];
        lines += [rule] if rule else [];
        lines += [prop("EXDATE", new(D, ms), zone) for ms in (excluded if rule else [])];
        lines += ["STATUS:TENTATIVE"] if ev["responseStatus"] == "tentative" else [];
        lines += [f"LAST-MODIFIED:{formatIcsUtc(ev['updatedAt'])}"] if ev["updatedAt"] else [];
        lines.append("END:VEVENT");
        # PUBLISH stays VALARM-free and attendee-free: overrides carry only the replacement time, with
        # the master's TZID form so the RECURRENCE-ID pairs with its rule occurrence.
        for o in (either(overrides.get(ev["id"]), []) if overrides else []) {
            if o["occurrenceMs"] not in excluded {
                times = [prop("DTSTART", o["startsAt"], zone), prop("DTEND", o["endsAt"], zone)];
                recurrence = prop("RECURRENCE-ID", new(D, o["occurrenceMs"]), zone);
                lines += head + [recurrence] + times + [summary, "END:VEVENT"];
            }
        }
    }
    return joinIcsLines(lines + ["END:VCALENDAR"]);
}

# What a TypeScript caller names: one edited occurrence, {occurrenceMs, startsAt, endsAt}.
type FeedOccurrenceOverride = any;
