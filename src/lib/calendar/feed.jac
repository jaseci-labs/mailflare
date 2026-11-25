glob:priv BYDAY: list[str] = "SU MO TU WE TH FR SA".split(),
          FREQ: any = {k: f"FREQ={k.upper()}" for k in ["daily", "weekly", "yearly"]},
          HEAD: str = """BEGIN:VCALENDAR VERSION:2.0 PRODID:-//Mailflare//Calendar//EN
              CALSCALE:GREGORIAN METHOD:PUBLISH""",
          TEXTS: list[str] = ["description", "location"],
          D: any = globalThis.Date,
          TTL: list[str] = ["REFRESH-INTERVAL;VALUE=DURATION:PT1H", "X-PUBLISHED-TTL:PT1H"],
          TWO_DIGITS: any = {k: "2-digit" for k in "month day hour minute second".split()};

# The wall-clock time of an instant in a zone, as an iCalendar local DATE-TIME.
def:priv zoned(value: any, tz: str) -> str {
    options = merged({"hourCycle": "h23", "year": "numeric"}, TWO_DIGITS, {"timeZone": tz});
    f = {"T": "T"};
    for p in new(globalThis.Intl.DateTimeFormat, "en-CA", options).formatToParts(value) {
        f.setdefault(p["type"], p["value"]);
    }
    return "".join([f.get(k, "00") for k in "year month day T hour minute second".split()]);
}

def:priv valid_zone(value: any) -> any {
    try {
        new(globalThis.Intl.DateTimeFormat, "en", record({"timeZone": value}));
        return value or NULL;
    } except Exception {
        return NULL;
    }
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
    (rep, n, until) = (ev["repeat"], ev["repeatInterval"], ev["repeatUntil"]);
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
