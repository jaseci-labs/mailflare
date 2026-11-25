glob:priv DAY_MS: int = 86400000,
          D: any = globalThis.Date,
          UTC: any = globalThis.Date.UTC,
          dim: any = lambda (y: int, m: int) -> int { new(D, UTC(y, m + 1, 0)).getUTCDate() },
          dow: any = lambda (y: int, m: int, d: int) -> int { new(D, UTC(y, m, d)).getUTCDay() },
          by_start: any = lambda (a: any, b: any) -> any { a.startsAt.localeCompare(b.startsAt) };

# A listed-days repeat steps day by day and filters by weekday, so its interval is always 1.
def:priv interval_of(ev: any) -> int {
    n = ev["repeatInterval"];
    return n if ev["repeat"] != "weekdays" and whole(n, 1, 999) else 1;
}

def:priv nth_weekday_date(y: int, m: int, wd: int, week: int) -> int {
    last = dim(y, m);
    if week == -1 {
        return last - (dow(y, m, last) - wd + 7) % 7;
    }
    # At most 35, and a month has at least 28 days: one step back always fits.
    date = 1 + (wd - dow(y, m, 1) + 7) % 7 + (week - 1) * 7;
    return date - 7 if date > last else date;
}

def:priv occurrence_start(ev: any, i: int) -> any {
    if i == 0 {
        return ev["startsAt"];
    }
    (rep, step, zone) = (ev["repeat"], i * interval_of(ev), normalizeTimeZone(ev["timeZone"]));
    f = zonedDateFields(ev["startsAt"], zone);
    (day, month) = (f.getUTCDate(), f.getUTCMonth());
    if rep == "monthly" or rep == "yearly" {
        f.setUTCDate(1);
        (dy, dm) = (0, step) if rep == "monthly" else (step, 0);
        f.setUTCFullYear(f.getUTCFullYear() + dy, month + dm);
        (y, m) = (f.getUTCFullYear(), f.getUTCMonth());
        (wd, wk) = (ev["repeatWeekday"], ev["repeatWeek"]);
        nth = rep == "monthly" and whole(wd, 0, 6) and (whole(wk, 1, 5) or wk == -1);
        anchor = either(ev["repeatAnchorDay"], day) if rep == "monthly" else day;
        day = nth_weekday_date(y, m, wd, wk) if nth else globalThis.Math.min(anchor, dim(y, m));
    } else {
        day += step * (7 if rep == "weekly" else 1);
    }
    f.setUTCDate(day);
    return dateFromZonedFields(f, zone);
}

# Index of the first rule occurrence worth generating for a window that opens at `t`.
def:priv first_index(ev: any, zone: any, t: any) -> int {
    (rep, n, floor) = (ev["repeat"], interval_of(ev), globalThis.Math.floor);
    (a, b) = (zonedDateFields(ev["startsAt"], zone), zonedDateFields(new(D, t), zone));
    years = b.getUTCFullYear() - a.getUTCFullYear();
    if rep == "monthly" {
        k = floor((years * 12 + b.getUTCMonth() - a.getUTCMonth() - 1) / n);
    } elif rep == "yearly" {
        k = floor((years - 1) / n);
    } else {
        k = floor((b.getTime() - a.getTime()) / (DAY_MS * n * (7 if rep == "weekly" else 1))) - 1;
    }
    return globalThis.Math.max(0, k);
}

def:priv row(ev: any, zone: any, key: any, s: any, e: any) -> any {
    try {
        att = globalThis.JSON.parse(ev["attendees"]);
    } except Exception {
        att = [];  # Old malformed data remains readable.
    }
    texts = {k: ev[k] for k in ["title", "description", "location"]};
    mid = {"attendees": att, "color": ev["color"], "repeat": ev["repeat"], "timeZone": zone};
    times = {"startsAt": s.toISOString(), "endsAt": e.toISOString()};
    return merged({"id": key, "seriesId": ev["id"]}, texts, mid, times);
}

# An override is one edited occurrence (RECURRENCE-ID): it replaces the rule occurrence at
# `occurrenceMs`, or adds an extra one when no rule occurrence has that start.
def expandToolEvents(events: any, start: any, end: any, cap: any = None, ov: any = None) -> any {
    cap = 500 if cap is None else globalThis.Number(cap);
    (out, t0, t1) = ([], start.getTime(), end.getTime());
    for ev in events {
        (id, rep, zone) = (ev["id"], ev["repeat"], normalizeTimeZone(ev["timeZone"]));
        (until, dur) = (ev["repeatUntil"], ev["endsAt"].getTime() - ev["startsAt"].getTime());
        i0 = 0 if rep == "none" else first_index(ev, zone, t0 - dur);
        excluded = parseExcludedOccurrences(ev["excludedOccurrences"]);
        days = parseCalendarRepeatDays(ev["repeatDays"]);
        byMs = {o["occurrenceMs"]: o for o in (either(ov.get(id), []) if ov else [])};
        ruleMs = [];
        for i in range(i0, i0 + (1 if rep == "none" else 400)) {
            at = occurrence_start(ev, i);
            ms = at.getTime();
            if ms >= t1 or (until and ms >= until.getTime()) {
                break;
            }
            ruleMs.append(ms);
            early = ms + dur <= t0 or ms in excluded;
            if early or (rep == "weekdays" and zonedDateFields(at, zone).getUTCDay() not in days) {
                continue;
            }
            o = byMs.get(ms);
            (s, e) = (o["startsAt"], o["endsAt"]) if o else (at, new(globalThis.Date, ms + dur));
            out.append(row(ev, zone, id if rep == "none" and not o else f"{id}@{ms}", s, e));
            if len(out) >= cap {
                return js_sort(out, by_start);
            }
        }
        # Overrides on no rule occurrence (RDATEs) are extra occurrences, unless excluded or outside.
        for (ms, o) in byMs.items() {
            inside = o["endsAt"].getTime() > t0 and o["startsAt"].getTime() < t1;
            if inside and ms not in ruleMs and ms not in excluded {
                out.append(row(ev, zone, f"{id}@{ms}", o["startsAt"], o["endsAt"]));
                if len(out) >= cap {
                    return js_sort(out, by_start);
                }
            }
        }
    }
    return js_sort(out, by_start);
}
