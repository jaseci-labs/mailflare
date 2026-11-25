# A whole quarter hour: the only times a booking may start or end at.
glob:priv QH: any = rx(r"^([01]\d|2[0-3]):(00|15|30|45)$"),
          arr: any = lambda (x: any) -> any { x if globalThis.Array.isArray(x) else [] },
          trim: any = lambda (x: any) -> any { x.trim() if isinstance(x, str) else "" },
          good: any = lambda (r: any) -> bool { QH.test(r["startTime"]) and QH.test(r["endTime"]) },
          span: any = lambda (r: any) -> any {
              timeToMinutes(r.endTime) - timeToMinutes(r.startTime)
          },
          uniq: any = lambda (xs: any) -> bool { new(globalThis.Set, xs).size == len(xs) },
          plain: any = lambda (v: any) -> any {
              sub(v.normalize("NFKD"), rx("[\u0300-\u036f]", "g"), "")
          },
          is_range: any = lambda (r: any) -> bool {
              is_object(r) and isinstance(r["startTime"], str) and isinstance(r["endTime"], str)
          };

def slugifyBookingName(value: any) -> str {
    s = sub(sub(plain(value).toLowerCase(), rx("[^a-z0-9]+", "g"), "-"), rx("^-|-$", "g"), "");
    return sub(s.slice(0, 80), rx("-$"), "");
}

def isValidBookingSlug(value: any) -> bool {
    return value.length <= 80 and rx("^[a-z0-9]+(?:-[a-z0-9]+)*$").test(value);
}

def normalizeBookingUsername(value: any = None) -> any {
    u = trim(value).toLowerCase();
    return u if rx(r"^(?=.*[a-z0-9])[a-z0-9._+-]{1,64}$").test(u) else NULL;
}

def bookingUsernameFromEmail(email: str) -> str {
    u = sub(plain(email.split("@")[0]).toLowerCase(), rx("[^a-z0-9._+-]+", "g"), "-");
    return either(normalizeBookingUsername(u.slice(0, 56)), "user");
}

def:priv json(text: any) -> any {
    try {
        return globalThis.JSON.parse(text);
    } except Exception {
        return NULL;
    }
}

# Older rows use the single time window: the fallback.
def parseBookingTimeRanges(value: any, fallback: any = None) -> list[any] {
    p = arr(json(value));
    return p if p.length and all([is_range(r) for r in p]) else ([fallback] if fallback else []);
}

def parseBookingEventInput(value: any = None) -> any {
    v = value if is_object(value) else record({});
    (name, desc, loc) = [trim(v[k]) for k in ["name", "description", "location"]];
    (sl, days, dur, hosts) = (v["slug"], v["weekdays"], v["durationMinutes"], v["hostIds"]);
    slug: any = sl.trim().toLowerCase() if isinstance(sl, str) else slugifyBookingName(name);
    hosts = [] if hosts is None else hosts;
    ok = is_object(value) and name and name.length <= 120 and isValidBookingSlug(slug);
    ok = ok and desc.length <= 2000 and loc.length <= 240 and whole(dur, 5, 480);
    ok = ok and globalThis.Array.isArray(hosts) and hosts.length <= 20 and uniq(hosts);
    ok = ok and all([isinstance(i, str) and bool(i) for i in hosts]) and len(arr(days)) > 0;
    pair = isinstance(v["startTime"], str) and isinstance(v["endTime"], str);
    one = [record({k: v[k] for k in ["startTime", "endTime"]})] if pair else NULL;
    ranges = arr(either(v["timeRanges"], one));
    ok = ok and uniq(days) and all([whole(d, 0, 6) for d in days]) and 0 < len(ranges) <= 12;
    ok = ok and all([is_range(r) and good(r) and span(r) >= dur for r in ranges]);
    by_start = lambda (a: any, b: any) -> any { a["startTime"].localeCompare(b["startTime"]) };
    rs = js_sort(ranges.slice(), by_start) if ok else [];
    ok = ok and not any([rs[i]["startTime"] < rs[i - 1]["endTime"] for i in range(1, len(rs))]);
    (tz, on) = (v["timeZone"], v["enabled"]);
    if not ok or not isinstance(tz, str) or not isValidTimeZone(tz) or not isinstance(on, bool) {
        return NULL;
    }
    color = normalizeCalendarColor(v["color"] if isinstance(v["color"], str) else None);
    times = {"startTime": rs[0]["startTime"], "endTime": rs[0]["endTime"], "timeRanges": rs};
    head = {"name": name, "slug": slug, "description": desc, "color": color, "hostIds": hosts};
    mid = {"durationMinutes": dur, "location": loc, "weekdays": sorted(days)};
    return merged(head, mid, times, {"timeZone": tz, "enabled": on});
}

def timeToMinutes(value: str) -> any {
    p = value.split(":");
    return globalThis.Number(p[0]) * 60 + globalThis.Number(first(p[1:]));
}

def slotFromLocalDate(ev: any, day: str, time: str) -> any {
    (want, m, dur, t) = (f"{day}T{time}", timeToMinutes(time), ev.durationMinutes, timeToMinutes);
    wall = new(globalThis.Date, f"{want}:00Z");
    ok = rx(r"^\d{4}-\d{2}-\d{2}$").test(day) and QH.test(time) and not globalThis.isNaN(wall);
    ok = ok and wall.toISOString().slice(0, 10) == day and wall.getUTCDay() in ev["weekdays"];
    fits = [t(r.startTime) <= m and m + dur <= t(r.endTime) for r in ev.timeRanges];
    start = dateFromZonedFields(wall, ev.timeZone) if ok and any(fits) else NULL;
    if not start or zonedDateFields(start, ev.timeZone).toISOString().slice(0, 16) != want {
        return NULL;
    }
    return {"startsAt": start, "endsAt": new(globalThis.Date, start.getTime() + dur * 60000)};
}

def parseBookingWeekdays(value: any) -> list[int] {
    return [day for day in arr(json(value)) if whole(day, 0, 6)];
}
