# Expansion runs per occurrence for the calendar views and the five-minute reminder cron, so it
# makes no closures and no tuples, and reads events and dates with JavaScript's own methods
# through `globalThis` (a direct call) instead of Jac's attribute and item lookups.
glob:priv by_start: any = lambda (a: any, b: any) -> any { a.startsAt.localeCompare(b.startsAt) };

def:priv get(o: any, k: str) -> any {
    return globalThis.Reflect.get(o, k);
}

def:priv time_of(d: any) -> float {
    return globalThis.Date.prototype.getTime.call(d);
}

def:priv valid_interval(value: any) -> any {
    return value if whole(value, 1, 999) else 1;
}

def:priv days_in_month(year: any, month: any) -> float {
    last = new(globalThis.Date, globalThis.Date.UTC(year, month + 1, 0));
    return globalThis.Date.prototype.getUTCDate.call(last);
}

def:priv weekday_of(year: any, month: any, day: any) -> float {
    return globalThis.Date.prototype.getUTCDay.call(new(globalThis.Date, globalThis.Date.UTC(year, month, day)));
}

def:priv nth_weekday_date(year: any, month: any, weekday: any, week: any) -> float {
    dim: float = days_in_month(year, month);
    if week == -1 {
        last_dow: float = weekday_of(year, month, dim);
        return dim - (last_dow - weekday + 7) % 7;
    }
    first_dow: float = weekday_of(year, month, 1);
    date: float = 1 + (weekday - first_dow + 7) % 7 + (week - 1) * 7;
    while date > dim {
        date -= 7;
    }
    return date;
}

def:priv has_nth_weekday(event: any) -> bool {
    weekday = get(event, "repeatWeekday");
    week = get(event, "repeatWeek");
    return get(event, "repeat") == "monthly"
        and whole(weekday, 0, 6)
        and (whole(week, 1, 5) or week == -1);
}

def:priv occurrence_start(event: any, index: float) -> any {
    if index == 0 {
        return get(event, "startsAt");
    }
    rep = get(event, "repeat");
    # A listed-days repeat steps day by day and filters by weekday, so its interval is always 1.
    interval: float = 1 if rep == "weekdays" else valid_interval(get(event, "repeatInterval"));
    zone = normalizeTimeZone(get(event, "timeZone"));
    fields = zonedDateFields(get(event, "startsAt"), zone);
    if rep == "monthly" {
        nth = has_nth_weekday(event);
        day = NULL;
        if not nth {
            day = either(get(event, "repeatAnchorDay"), globalThis.Date.prototype.getUTCDate.call(fields));
        }
        globalThis.Date.prototype.setUTCDate.call(fields, 1);
        month0: float = globalThis.Date.prototype.getUTCMonth.call(fields);
        globalThis.Date.prototype.setUTCMonth.call(fields, month0 + index * interval);
        year = globalThis.Date.prototype.getUTCFullYear.call(fields);
        month = globalThis.Date.prototype.getUTCMonth.call(fields);
        if nth {
            wd = get(event, "repeatWeekday");
            wk = get(event, "repeatWeek");
            globalThis.Date.prototype.setUTCDate.call(fields, nth_weekday_date(year, month, wd, wk));
        } else {
            globalThis.Date.prototype.setUTCDate.call(fields, globalThis.Math.min(day, days_in_month(year, month)));
        }
    } elif rep == "yearly" {
        day = globalThis.Date.prototype.getUTCDate.call(fields);
        month = globalThis.Date.prototype.getUTCMonth.call(fields);
        globalThis.Date.prototype.setUTCDate.call(fields, 1);
        year0: float = globalThis.Date.prototype.getUTCFullYear.call(fields);
        globalThis.Date.prototype.setUTCFullYear.call(fields, year0 + index * interval);
        globalThis.Date.prototype.setUTCMonth.call(fields, month);
        days = days_in_month(globalThis.Date.prototype.getUTCFullYear.call(fields), month);
        globalThis.Date.prototype.setUTCDate.call(fields, globalThis.Math.min(day, days));
    } else {
        step: float = index * interval * (7 if rep == "weekly" else 1);
        day0: float = globalThis.Date.prototype.getUTCDate.call(fields);
        globalThis.Date.prototype.setUTCDate.call(fields, day0 + step);
    }
    return dateFromZonedFields(fields, zone);
}

def:priv attendees_of(event: any) -> any {
    attendees: any = [];
    try {
        attendees = globalThis.JSON.parse(get(event, "attendees"));
    } except Exception {
        # Old malformed data remains readable.
    }
    return attendees;
}

def:priv occurrence_row(event: any, zone: any, id: any, s: any, e: any) -> any {
    out: any = globalThis.Object();
    out.id = id;
    out.seriesId = get(event, "id");
    out.title = get(event, "title");
    out.description = get(event, "description");
    out.location = get(event, "location");
    out.attendees = attendees_of(event);
    out.color = get(event, "color");
    out.repeat = get(event, "repeat");
    out.timeZone = zone;
    out.startsAt = globalThis.Date.prototype.toISOString.call(s);
    out.endsAt = globalThis.Date.prototype.toISOString.call(e);
    return out;
}

def:priv first_index(event: any, first: any, target: any, interval: float) -> float {
    rep = get(event, "repeat");
    ty: float = globalThis.Date.prototype.getUTCFullYear.call(target);
    fy: float = globalThis.Date.prototype.getUTCFullYear.call(first);
    years: float = ty - fy;
    if rep == "monthly" {
        tm: float = globalThis.Date.prototype.getUTCMonth.call(target);
        fm: float = globalThis.Date.prototype.getUTCMonth.call(first);
        months: float = years * 12 + tm - fm;
        return globalThis.Math.max(0, globalThis.Math.floor((months - 1) / interval));
    }
    if rep == "yearly" {
        return globalThis.Math.max(0, globalThis.Math.floor((years - 1) / interval));
    }
    step: float = (7 if rep == "weekly" else 1) * interval;
    span: float = time_of(target) - time_of(first);
    return globalThis.Math.max(0, globalThis.Math.floor(span / (86400000 * step)) - 1);
}

# An override is one edited occurrence (RECURRENCE-ID): it replaces the rule occurrence at
# `occurrenceMs`, or adds an extra one when no rule occurrence has that start.
def expandToolEvents(events: any, start: any, end: any, max: any = None, overrides: any = None) -> any {
    cap: float = 500 if max is None else globalThis.Number(max);
    result: list[any] = [];
    t0: float = time_of(start);
    for event in events {
        rep = get(event, "repeat");
        starts_at = get(event, "startsAt");
        duration: float = time_of(get(event, "endsAt")) - time_of(starts_at);
        zone = normalizeTimeZone(get(event, "timeZone"));
        first = zonedDateFields(starts_at, zone);
        target = zonedDateFields(new(globalThis.Date, t0 - duration), zone);
        interval: float = 1 if rep == "weekdays" else valid_interval(get(event, "repeatInterval"));
        initial: float = first_index(event, first, target, interval);
        excluded = new(globalThis.Set, parseExcludedOccurrences(get(event, "excludedOccurrences")));
        days = parseCalendarRepeatDays(get(event, "repeatDays"));
        by_ms: dict[any, any] = {};
        listed = NULL if nil(overrides) else overrides.get(get(event, "id"));
        for edit in ([] if nil(listed) else listed) {
            by_ms[get(edit, "occurrenceMs")] = edit;
        }
        rule_ms = new(globalThis.Set);
        until = get(event, "repeatUntil");
        index: float = 0 if rep == "none" else initial;
        stop: float = 1 if rep == "none" else initial + 400;
        while index < stop {
            at = occurrence_start(event, index);
            index += 1;
            ms: float = time_of(at);
            if ms >= globalThis.Number(end) or (until and ms >= globalThis.Number(until)) {
                break;
            }
            globalThis.Set.prototype.add.call(rule_ms, ms);
            if ms + duration <= t0 or globalThis.Set.prototype.has.call(excluded, ms) {
                continue;
            }
            if rep == "weekdays" {
                weekday = globalThis.Date.prototype.getUTCDay.call(zonedDateFields(at, zone));
                if weekday not in days {
                    continue;
                }
            }
            edit = by_ms.get(ms);
            if edit {
                s = get(edit, "startsAt");
                e = get(edit, "endsAt");
                key = globalThis.String(get(event, "id")) + "@" + globalThis.String(ms);
            } else {
                s = at;
                e = new(globalThis.Date, ms + duration);
                key = get(event, "id") if rep == "none" else globalThis.String(get(event, "id")) + "@" + globalThis.String(ms);
            }
            result.append(occurrence_row(event, zone, key, s, e));
            if len(result) >= cap {
                return js_sort(result, by_start);
            }
        }
        # Overrides on no rule occurrence (RDATEs) are extra, unless excluded or outside the window.
        for edit in by_ms.values() {
            occurrence = get(edit, "occurrenceMs");
            if globalThis.Set.prototype.has.call(rule_ms, occurrence) or globalThis.Set.prototype.has.call(excluded, occurrence) {
                continue;
            }
            s = get(edit, "startsAt");
            e = get(edit, "endsAt");
            if globalThis.Number(e) <= t0 or globalThis.Number(s) >= globalThis.Number(end) {
                continue;
            }
            key = globalThis.String(get(event, "id")) + "@" + globalThis.String(occurrence);
            result.append(occurrence_row(event, zone, key, s, e));
            if len(result) >= cap {
                return js_sort(result, by_start);
            }
        }
    }
    return js_sort(result, by_start);
}
