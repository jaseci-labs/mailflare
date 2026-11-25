glob:priv BYDAY: list[str] = "SU MO TU WE TH FR SA".split(),
          FREQ: any = {k: f"FREQ={k.upper()}" for k in ["daily", "weekly", "yearly"]},
          HEAD: str = """BEGIN:VCALENDAR VERSION:2.0 PRODID:-//Mailflare//Calendar//EN
              CALSCALE:GREGORIAN""",
          ATTEND: str = "ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:",
          D: any = globalThis.Date;

# The RRULE of the series; absent or "none" writes none. `repeatUntil` is written in UTC as it stands.
def:priv rrule(input: any) -> any {
    (rep, n, until) = (at(input, "repeat"), at(input, "repeatInterval"), at(input, "repeatUntil"));
    (wd, week) = (at(input, "repeatWeekday"), at(input, "repeatWeek"));
    anchor = at(input, "repeatAnchorDay");
    if not rep or rep == "none" {
        return NULL;
    } elif rep in FREQ {
        parts = [FREQ[rep]];
    } elif rep == "monthly" and whole(wd, 0, 6) and (whole(week, 1, 5) or week == -1) {
        parts = ["FREQ=MONTHLY", f"BYDAY={week}{BYDAY[wd]}"];
    } elif rep == "monthly" {
        parts = ["FREQ=MONTHLY"] + ([f"BYMONTHDAY={globalThis.String(anchor)}"] if anchor else []);
    } else {
        days = sorted({day for day in at(input, "repeatDays", []) if whole(day, 0, 6)});
        if not days {
            return NULL;
        }
        parts = ["FREQ=WEEKLY", "BYDAY=" + ",".join([BYDAY[day] for day in days])];
    }
    # A listed-days repeat steps day by day, so its interval is always 1 and never written.
    stepped = rep != "weekdays" and globalThis.Number.isInteger(n) and n > 1;
    parts += [f"INTERVAL={n}"] if stepped else [];
    parts += [f"UNTIL={formatIcsUtc(until)}"] if until else [];
    return "RRULE:" + ";".join(parts);
}

# One event or series. PUBLISH is a plain event without organizer or RSVP; `sequence` is bumped on
# every update so guests ignore stale mail; `overrides` become VEVENTs with a RECURRENCE-ID and
# `excludedOccurrences` EXDATEs.
def createCalendarInvitation(input: any) -> any {
    (method, sender, seq) = (at(input, "method"), at(input, "organizer"), at(input, "sequence"));
    organizer = sender if method != "PUBLISH" and sender and isIcsAddress(sender) else NULL;
    sequence = seq if globalThis.Number.isSafeInteger(seq) and seq >= 0 else 0;
    (stamp, rule, utc) = (f"DTSTAMP:{formatIcsUtc(new(D))}", rrule(input), formatIcsUtc);
    ms_ok = lambda (ms: any) -> bool { globalThis.Number.isSafeInteger(ms) and ms >= 0 };
    excluded = sorted({ms for ms in at(input, "excludedOccurrences", []) if ms_ok(ms)});
    rsvp = at(input, "attendees", []) if organizer else [];
    guests: list[str] = [ATTEND + a for a in rsvp if isIcsAddress(a)];
    parties = guests if not organizer else [f"ORGANIZER:mailto:{organizer}"] + guests;
    head = ["BEGIN:VEVENT", f"UID:{input['uid']}@mailflare", stamp, f"SEQUENCE:{sequence}"];
    times = lambda (s: any, e: any) -> any { [f"DTSTART:{utc(s)}", f"DTEND:{utc(e)}"] };
    # The times are read before the texts, as the lines are written.
    (opening, title) = (times(input["startsAt"], input["endsAt"]), escapeIcsText(input["title"]));
    (desc, place) = (escapeIcsText(input["description"]), escapeIcsText(input["location"]));
    texts = [f"SUMMARY:{title}", f"DESCRIPTION:{desc}", f"LOCATION:{place}"] + parties;
    lines = HEAD.split() + [f"METHOD:{either(method, 'REQUEST')}"] + head + opening + texts;
    exdates = ",".join([formatIcsUtc(new(D, ms)) for ms in excluded]);
    lines += ([rule] if rule else []) + ([f"EXDATE:{exdates}"] if excluded else []);
    # One best-effort reminder; -PTnM is always a valid DURATION, so large offsets stay in minutes.
    reminder = at(input, "reminderMinutes");
    trigger = f"TRIGGER:-PT{globalThis.String(reminder)}M";
    alarm = ["BEGIN:VALARM", "ACTION:DISPLAY", f"DESCRIPTION:{title}", trigger, "END:VALARM"];
    lines += (alarm if not nil(reminder) else []) + ["END:VEVENT"];
    for o in at(input, "overrides", []) {
        recurrence = f"RECURRENCE-ID:{formatIcsUtc(o['recurrenceId'])}";
        lines += head + [recurrence] + times(o["startsAt"], o["endsAt"]) + texts + ["END:VEVENT"];
    }
    return new(globalThis.TextEncoder).encode(joinIcsLines(lines + ["END:VCALENDAR"])).buffer;
}
