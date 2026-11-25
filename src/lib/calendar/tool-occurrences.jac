glob:priv DAY_MS: int = 86400000;

def:priv whole(value: any, low: int, high: int) -> bool {
    return globalThis.Number.isInteger(value) and low <= value <= high;
}

"""Step between recurrences. A listed-days repeat steps day by day and filters by weekday, so its interval is always 1."""
def:priv interval_of(event: any) -> int {
    step = event["repeatInterval"];
    return step if event["repeat"] != "weekdays" and whole(step, 1, 999) else 1;
}

def:priv daysInMonth(year: int, month: int) -> int {
    return new(globalThis.Date, globalThis.Date.UTC(year, month + 1, 0)).getUTCDate();
}

def:priv weekday_of(year: int, month: int, day: int) -> int {
    return new(globalThis.Date, globalThis.Date.UTC(year, month, day)).getUTCDay();
}

def:priv nthWeekdayDate(year: int, month: int, weekday: int, week: int) -> int {
    dim = daysInMonth(year, month);
    if week == -1 {
        return dim - ((weekday_of(year, month, dim) - weekday + 7) % 7);
    }
    date = 1 + ((weekday - weekday_of(year, month, 1) + 7) % 7) + (week - 1) * 7;
    while date > dim {
        date -= 7;
    }
    return date;
}

def:priv is_nth_weekday(event: any) -> bool {
    week = event["repeatWeek"];
    return event["repeat"] == "monthly"
        and whole(event["repeatWeekday"], 0, 6)
        and (whole(week, 1, 5) or week == -1);
}

def:priv occurrenceStart(event: any, index: int) -> any {
    if index == 0 {
        return event["startsAt"];
    }
    repeat = event["repeat"];
    interval = interval_of(event);
    zone = normalizeTimeZone(event["timeZone"]);
    fields = zonedDateFields(event["startsAt"], zone);
    if repeat == "monthly" {
        day = either(event["repeatAnchorDay"], fields.getUTCDate());
        fields.setUTCDate(1);
        fields.setUTCMonth(fields.getUTCMonth() + index * interval);
        (year, month) = (fields.getUTCFullYear(), fields.getUTCMonth());
        fields.setUTCDate(
            nthWeekdayDate(year, month, event["repeatWeekday"], event["repeatWeek"])
                if is_nth_weekday(event)
                else globalThis.Math.min(day, daysInMonth(year, month)),
        );
    } elif repeat == "yearly" {
        (day, month) = (fields.getUTCDate(), fields.getUTCMonth());
        fields.setUTCDate(1);
        fields.setUTCFullYear(fields.getUTCFullYear() + index * interval);
        fields.setUTCMonth(month);
        fields.setUTCDate(globalThis.Math.min(day, daysInMonth(fields.getUTCFullYear(), month)));
    } else {
        fields.setUTCDate(
            fields.getUTCDate() + index * interval * (7 if repeat == "weekly" else 1)
        );
    }
    return dateFromZonedFields(fields, zone);
}

"""Index of the first rule occurrence worth generating for a window that opens at `target` (zoned fields)."""
def:priv first_index(event: any, first: any, target: any) -> int {
    repeat = event["repeat"];
    interval = interval_of(event);
    years = target.getUTCFullYear() - first.getUTCFullYear();
    floor = globalThis.Math.floor;
    if repeat == "monthly" {
        skipped = floor((years * 12 + target.getUTCMonth() - first.getUTCMonth() - 1) / interval);
    } elif repeat == "yearly" {
        skipped = floor((years - 1) / interval);
    } else {
        step = (7 if repeat == "weekly" else 1) * interval;
        skipped = floor((target.getTime() - first.getTime()) / (DAY_MS * step)) - 1;
    }
    return globalThis.Math.max(0, skipped);
}

def:priv by_start(a: any, b: any) -> int {
    return a["startsAt"].localeCompare(b["startsAt"]);
}

def:priv sorted_rows(rows: list[any]) -> list[any] {
    return globalThis.Array.prototype.sort.call(rows, by_start);
}

"""
The occurrences of `events` that overlap [start, end), oldest first, at most `limit` (500). An override is one
edited occurrence (RECURRENCE-ID): it replaces the rule occurrence at `occurrenceMs`, or adds an extra one
when no rule occurrence has that start.
"""
def expandToolEvents(
    events: any, start: any, end: any, limit: any = None, overrides: any = None
) -> list[any] {
    limit = 500 if limit is None else limit;
    result: list[any] = [];
    for event in events {
        (id, repeat) = (event["id"], event["repeat"]);
        duration = event["endsAt"].getTime() - event["startsAt"].getTime();
        zone = normalizeTimeZone(event["timeZone"]);
        until = event["repeatUntil"];
        def row(key: any, startsAt: any, endsAt: any) -> dict[str, any] {
            attendees: any = [];
            try {
                attendees = globalThis.JSON.parse(event["attendees"]);
            } except Exception {
                # Old malformed data remains readable.
                attendees = [];
            }
            return {
                "id": key,
                "seriesId": id,
                "title": event["title"],
                "description": event["description"],
                "location": event["location"],
                "attendees": attendees,
                "color": event["color"],
                "repeat": repeat,
                "timeZone": zone,
                "startsAt": startsAt.toISOString(),
                "endsAt": endsAt.toISOString(),
            };
        }
        initial = 0
            if repeat == "none"
            else first_index(
                event,
                zonedDateFields(event["startsAt"], zone),
                zonedDateFields(new(globalThis.Date, start.getTime() - duration), zone),
            );
        excluded = parseExcludedOccurrences(event["excludedOccurrences"]);
        days = parseCalendarRepeatDays(event["repeatDays"]);
        byMs: dict[any, any] = {
            o["occurrenceMs"]: o
            for o in (either(overrides.get(id), []) if overrides else [])
        };
        ruleMs: list[int] = [];
        for index in range(initial, initial + (1 if repeat == "none" else 400)) {
            at = occurrenceStart(event, index);
            ms = at.getTime();
            if ms >= end.getTime() or (until and ms >= until.getTime()) {
                break;
            }
            ruleMs.append(ms);
            if ms + duration <= start.getTime() or ms in excluded {
                continue;
            }
            if repeat == "weekdays" and zonedDateFields(at, zone).getUTCDay() not in days {
                continue;
            }
            moved = byMs.get(ms);
            if moved {
                result.append(row(f"{id}@{ms}", moved["startsAt"], moved["endsAt"]));
            } else {
                result.append(
                    row(
                        id if repeat == "none" else f"{id}@{ms}",
                        at,
                        new(globalThis.Date, ms + duration),
                    ),
                );
            }
            if len(result) >= limit {
                return sorted_rows(result);
            }
        }
        # Overrides on no rule occurrence (RDATEs) are extra occurrences, unless excluded or outside the window.
        for (ms, moved) in byMs.items() {
            if ms in ruleMs or ms in excluded {
                continue;
            }
            if moved["endsAt"].getTime() <= start.getTime()
                or moved["startsAt"].getTime() >= end.getTime()
            {
                continue;
            }
            result.append(row(f"{id}@{ms}", moved["startsAt"], moved["endsAt"]));
            if len(result) >= limit {
                return sorted_rows(result);
            }
        }
    }
    return sorted_rows(result);
}
