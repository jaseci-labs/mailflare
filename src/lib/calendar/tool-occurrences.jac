glob:priv D: any = globalThis.Date,
          UTC: any = globalThis.Date.UTC,
          dim: any = lambda (y: int, m: int) -> int { new(D, UTC(y, m + 1, 0)).getUTCDate() },
          dow: any = lambda (y: int, m: int, d: int) -> int { new(D, UTC(y, m, d)).getUTCDay() },
          by_start: any = lambda (a: any, b: any) -> any { a.startsAt.localeCompare(b.startsAt) },
          # Listed days step day by day and filter by weekday, so their interval is always 1.
          every: any = lambda (rep: str, n: any) -> int {
              n if rep != "weekdays" and whole(n, 1, 999) else 1
          };

def:priv nth_weekday_date(y: int, m: int, wd: int, week: int) -> int {
    # At most 35, and a month has at least 28 days: one step back always fits.
    (last, d) = (dim(y, m), 1 + (wd - dow(y, m, 1) + 7) % 7 + (week - 1) * 7);
    return last - (dow(y, m, last) - wd + 7) % 7 if week == -1 else (d - 7 if d > last else d);
}

# The occurrence `step` intervals after the first.
def:priv occurrence_start(ev: any, zone: any, step: int) -> any {
    if step == 0 {
        return ev["startsAt"];
    }
    (rep, f) = (ev["repeat"], zonedDateFields(ev["startsAt"], zone));
    (day, month, mo) = (f.getUTCDate(), f.getUTCMonth(), rep == "monthly");
    if mo or rep == "yearly" {
        f.setUTCFullYear(f.getUTCFullYear() + (0 if mo else step), month + (step if mo else 0), 1);
        (y, m, wd, wk) = (
            f.getUTCFullYear(),
            f.getUTCMonth(),
            ev["repeatWeekday"],
            ev["repeatWeek"],
        );
        nth = mo and whole(wd, 0, 6) and (whole(wk, 1, 5) or wk == -1);
        anchor = either(ev["repeatAnchorDay"], day) if mo else day;
        day = nth_weekday_date(y, m, wd, wk) if nth else globalThis.Math.min(anchor, dim(y, m));
    } else {
        day += step * (7 if rep == "weekly" else 1);
    }
    f.setUTCDate(day);
    return dateFromZonedFields(f, zone);
}

# Index of the first rule occurrence worth generating for a window that opens at `t`.
def:priv first_index(ev: any, zone: any, n: int, t: any) -> int {
    (rep, floor) = (ev["repeat"], globalThis.Math.floor);
    (a, b) = (zonedDateFields(ev["startsAt"], zone), zonedDateFields(new(D, t), zone));
    years = b.getUTCFullYear() - a.getUTCFullYear();
    months = years * 12 + b.getUTCMonth() - a.getUTCMonth();
    days = floor((b.getTime() - a.getTime()) / (86400000 * n * (7 if rep == "weekly" else 1))) - 1;
    k = {"monthly": floor((months - 1) / n), "yearly": floor((years - 1) / n)}.get(rep, days);
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
        n = every(rep, ev["repeatInterval"]);
        i0 = 0 if rep == "none" else first_index(ev, zone, n, t0 - dur);
        excluded = parseExcludedOccurrences(ev["excludedOccurrences"]);
        days = parseCalendarRepeatDays(ev["repeatDays"]);
        byMs = {o["occurrenceMs"]: o for o in (either(ov.get(id), []) if ov else [])};
        (taken, found) = ([*excluded], []);
        for i in range(i0, i0 + (1 if rep == "none" else 400)) {
            at = occurrence_start(ev, zone, i * n);
            ms = at.getTime();
            if ms >= t1 or (until and ms >= until.getTime()) {
                break;
            }
            taken.append(ms);
            shown = rep != "weekdays" or zonedDateFields(at, zone).getUTCDay() in days;
            if ms + dur > t0 and ms not in excluded and shown {
                o = byMs.get(ms);
                (s, e) = (o["startsAt"], o["endsAt"]) if o else (at, new(D, ms + dur));
                found.append((id if rep == "none" and not o else f"{id}@{ms}", s, e));
            }
        }
        # Overrides on no rule occurrence (RDATEs) are extra, unless excluded or outside the window.
        for (ms, o) in byMs.items() {
            if ms not in taken and o["endsAt"].getTime() > t0 and o["startsAt"].getTime() < t1 {
                found.append((f"{id}@{ms}", o["startsAt"], o["endsAt"]));
            }
        }
        # In the order they were found, up to `cap` rows in all.
        for (key, s, e) in found {
            out.append(row(ev, zone, key, s, e));
            if len(out) >= cap {
                return js_sort(out, by_start);
            }
        }
    }
    return js_sort(out, by_start);
}
