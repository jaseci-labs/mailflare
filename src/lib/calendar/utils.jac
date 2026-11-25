glob:priv INVITE_BYDAY: list[str] = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"],
          FREQ: dict[str, str] = {
              "daily": "FREQ=DAILY",
              "weekly": "FREQ=WEEKLY",
              "yearly": "FREQ=YEARLY",
          };

def:priv whole(value: any, low: int, high: int) -> bool {
    return globalThis.Number.isInteger(value) and low <= value <= high;
}

"""Safe non-negative integers of a list, deduplicated and ascending."""
def:priv instants(values: any) -> list[int] {
    return sorted({ms for ms in values if globalThis.Number.isSafeInteger(ms) and ms >= 0});
}

"""The RRULE of the series; absent or "none" writes none. `repeatUntil` is written in UTC as it stands."""
def:priv invitationRecurrenceRule(input: any) -> any {
    repeat = at(input, "repeat");
    if not repeat or repeat == "none" {
        return NULL;
    }
    parts: list[str] = [];
    if repeat in FREQ {
        parts = [FREQ[repeat]];
    } elif repeat == "monthly" {
        parts = ["FREQ=MONTHLY"];
        (weekday, week, anchor) = (
            at(input, "repeatWeekday"),
            at(input, "repeatWeek"),
            at(input, "repeatAnchorDay"),
        );
        if whole(weekday, 0, 6) and (whole(week, 1, 5) or week == -1) {
            parts.append(f"BYDAY={week}{INVITE_BYDAY[weekday]}");
        } elif anchor {
            parts.append(f"BYMONTHDAY={globalThis.String(anchor)}");
        }
    } else {
        days = sorted({day for day in at(input, "repeatDays", []) if whole(day, 0, 6)});
        if not days {
            return NULL;
        }
        parts = ["FREQ=WEEKLY", "BYDAY=" + ",".join([INVITE_BYDAY[day] for day in days])];
    }
    # A listed-days repeat steps day by day, so its interval is always 1 and never written.
    interval = at(input, "repeatInterval");
    if repeat != "weekdays" and globalThis.Number.isInteger(interval) and interval > 1 {
        parts.append(f"INTERVAL={interval}");
    }
    if at(input, "repeatUntil") {
        parts.append(f"UNTIL={formatIcsUtc(input['repeatUntil'])}");
    }
    return "RRULE:" + ";".join(parts);
}

"""
An iCalendar file for one event or series. METHOD PUBLISH is a plain event without organizer or RSVP.
`sequence` is 0 for a new UID and bumped on every update so guests ignore stale mail; each of `overrides`
becomes a VEVENT with a RECURRENCE-ID, and `excludedOccurrences` (epoch ms) are written as EXDATE, in UTC.
"""
def createCalendarInvitation(input: any) -> any {
    method = at(input, "method");
    sender = at(input, "organizer");
    organizer = sender if method != "PUBLISH" and sender and isIcsAddress(sender) else NULL;
    seq = at(input, "sequence");
    sequence = seq if globalThis.Number.isSafeInteger(seq) and seq >= 0 else 0;
    stamp = formatIcsUtc(new(globalThis.Date));
    rule = invitationRecurrenceRule(input);
    excluded = instants(at(input, "excludedOccurrences", []));
    parties: list[str] = [];
    if organizer {
        parties = [f"ORGANIZER:mailto:{organizer}"] + [
            f"ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:{address}"
            for address in at(input, "attendees", [])
            if isIcsAddress(address)
        ];
    }
    head = [
        "BEGIN:VEVENT",
        f"UID:{input['uid']}@mailflare",
        f"DTSTAMP:{stamp}",
        f"SEQUENCE:{sequence}",
    ];
    def times(starts: any, ends: any) -> list[str] {
        return [f"DTSTART:{formatIcsUtc(starts)}", f"DTEND:{formatIcsUtc(ends)}"];
    }
    # The times are read before the texts, as the lines are written.
    opening = times(input["startsAt"], input["endsAt"]);
    texts = [
        f"SUMMARY:{escapeIcsText(input['title'])}",
        f"DESCRIPTION:{escapeIcsText(input['description'])}",
        f"LOCATION:{escapeIcsText(input['location'])}",
    ]
        + parties;
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Mailflare//Calendar//EN",
        "CALSCALE:GREGORIAN",
        f"METHOD:{either(method, 'REQUEST')}",
    ]
        + head
        + opening
        + texts;
    if rule {
        lines.append(rule);
    }
    if excluded {
        stamps = ",".join([formatIcsUtc(new(globalThis.Date, ms)) for ms in excluded]);
        lines.append(f"EXDATE:{stamps}");
    }
    # One best-effort reminder; -PTnM is always a valid DURATION, so large offsets stay in minutes.
    reminder = at(input, "reminderMinutes");
    if not nil(reminder) {
        lines += [
            "BEGIN:VALARM",
            "ACTION:DISPLAY",
            f"DESCRIPTION:{escapeIcsText(input['title'])}",
            f"TRIGGER:-PT{globalThis.String(reminder)}M",
            "END:VALARM",
        ];
    }
    lines.append("END:VEVENT");
    for moved in at(input, "overrides", []) {
        lines += head
            + [f"RECURRENCE-ID:{formatIcsUtc(moved['recurrenceId'])}"]
            + times(moved["startsAt"], moved["endsAt"])
            + texts
            + ["END:VEVENT"];
    }
    lines.append("END:VCALENDAR");
    return new(globalThis.TextEncoder).encode(joinIcsLines(lines)).buffer;
}
