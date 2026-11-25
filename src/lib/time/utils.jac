# Formatting runs per message row and per calendar occurrence, so the paths below make no
# closures and no tuples, and call JavaScript's own methods through `globalThis` (a direct call)
# instead of Jac's attribute and item lookups.
glob:priv FIELDS: dict[any, any] = {},
          DISPLAY: dict[any, any] = {},
          ZONES: dict[any, any] = {},
          DTF: any = globalThis.Intl.DateTimeFormat,
          FIELD_OPTIONS: any = {
              "year": "numeric",
              "month": "2-digit",
              "day": "2-digit",
              "hour": "2-digit",
              "minute": "2-digit",
              "second": "2-digit",
              "hourCycle": "h23",
          },
          user_zone: any = None;

# A cache of at most 64 entries is emptied, not trimmed, when full.
def:priv remember(cache: dict[any, any], key: any, value: any) -> any {
    if len(cache) >= 64 {
        cache.clear();
    }
    cache[key] = value;
    return value;
}

def:priv zone_of(key: any) -> any {
    try {
        return new(DTF, "en-US", record({"timeZone": key})).resolvedOptions().timeZone;
    } except Exception {
        return NULL;
    }
}

def normalizeTimeZone(value: any = None) -> str {
    key = value or "UTC";
    zone = ZONES.get(key);
    if not zone {
        zone = remember(ZONES, key, either(zone_of(key), "UTC"));
    }
    return zone;
}

def isValidTimeZone(value: any) -> bool {
    return not nil(zone_of(value));
}

def getUserTimeZone -> str {
    window = globalThis.Reflect.get(globalThis, "window");
    if window is None {
        return "UTC";
    }
    if user_zone {
        return user_zone;
    }
    zone = DTF().resolvedOptions().timeZone or "UTC";
    try {
        saved = either(window.localStorage.getItem("mailflare-user-time-zone"), "null");
        saved = globalThis.JSON.parse(saved);
        tz = NULL if nil(saved) else saved["timeZone"];
        zone = normalizeTimeZone(tz) if isinstance(tz, str) and isValidTimeZone(tz) else zone;
    } except Exception {
        # Device time remains available without storage.
    }
    user_zone = zone;
    return zone;
}

def clearUserTimeZoneCache {
    user_zone = None;
}

def getRequestTimeZone(request: any, preferredTimeZone: any = None) -> str {
    z = preferredTimeZone;
    z = new(globalThis.URL, request.url).searchParams.get("timeZone") if nil(z) else z;
    return normalizeTimeZone(request.headers.get("X-Time-Zone") if nil(z) else z);
}

# The interface language the language provider keeps on `<html lang>`; unset or on the server: default.
def getDisplayLocale -> any {
    document = globalThis.Reflect.get(globalThis, "document");
    if document is None {
        return None;
    }
    return globalThis.Reflect.get(document.documentElement, "lang") or None;
}

def formatUserDate(value: any, options: any) -> str {
    tz = globalThis.Reflect.get(options, "timeZone");
    if not isinstance(tz, str) {
        tz = getUserTimeZone();
    }
    locale = getDisplayLocale();
    name = "default" if locale is None else locale;
    key = f"{name}\u0000{tz}\u0000{globalThis.JSON.stringify(options)}";
    fmt = DISPLAY.get(key);
    if not fmt {
        fmt = remember(DISPLAY, key, new(DTF, locale, merged(options, {"timeZone": tz})));
    }
    format = globalThis.Reflect.get(fmt, "format");
    return globalThis.Function.prototype.call.call(format, fmt, new(globalThis.Date, value));
}

def formatUserDateTimeLocal(value: any) -> str {
    return zonedDateFields(value, getUserTimeZone()).toISOString().slice(0, 16);
}

def parseUserDateTimeLocal(value: any) -> any {
    m = rx(r"^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$").exec(value);
    if not m {
        return NULL;
    }
    fields = new(globalThis.Date, 0);
    month: float = globalThis.Number(m[2]);
    fields.setUTCFullYear(globalThis.Number(m[1]), month - 1, globalThis.Number(m[3]));
    fields.setUTCHours(globalThis.Number(m[4]), globalThis.Number(m[5]), 0, 0);
    if fields.toISOString().slice(0, 16) != value {
        return NULL;
    }
    return dateFromZonedFields(fields, getUserTimeZone());
}

def:priv field_formatter(timeZone: any) -> any {
    dtf = FIELDS.get(timeZone);
    if not dtf {
        dtf = remember(FIELDS, timeZone, new(DTF, "en-US", merged(FIELD_OPTIONS, {"timeZone": timeZone})));
    }
    return dtf;
}

"""A UTC date used only to do arithmetic on the timezone's wall-clock fields."""
def zonedDateFields(value: any, timeZone: any) -> any {
    parts = globalThis.Intl.DateTimeFormat.prototype.formatToParts.call(field_formatter(timeZone), value);
    # `Object.fromEntries` of the parts: the last part of a type wins, a missing one reads NaN.
    year: any = None;
    month: any = None;
    day: any = None;
    hour: any = None;
    minute: any = None;
    second: any = None;
    for part in parts {
        kind: str = globalThis.Reflect.get(part, "type");
        if kind == "year" {
            year = globalThis.Reflect.get(part, "value");
        } elif kind == "month" {
            month = globalThis.Reflect.get(part, "value");
        } elif kind == "day" {
            day = globalThis.Reflect.get(part, "value");
        } elif kind == "hour" {
            hour = globalThis.Reflect.get(part, "value");
        } elif kind == "minute" {
            minute = globalThis.Reflect.get(part, "value");
        } elif kind == "second" {
            second = globalThis.Reflect.get(part, "value");
        }
    }
    result = new(globalThis.Date, 0);
    m: float = globalThis.Number(month);
    globalThis.Date.prototype.setUTCFullYear.call(result, globalThis.Number(year), m - 1, globalThis.Number(day));
    globalThis.Date.prototype.setUTCHours.call(
        result,
        globalThis.Number(hour),
        globalThis.Number(minute),
        globalThis.Number(second),
        globalThis.Date.prototype.getUTCMilliseconds.call(value),
    );
    return result;
}

def:priv wall_at(t: float, tz: any) -> float {
    return globalThis.Date.prototype.getTime.call(zonedDateFields(new(globalThis.Date, t), tz));
}

def:priv by_time(a: any, b: any) -> any {
    return a.getTime() - b.getTime();
}

"""Use the earlier instant for repeated times and move forward across missing times."""
def dateFromZonedFields(fields: any, tz: any) -> any {
    wall: float = globalThis.Date.prototype.getTime.call(fields);
    # The distinct offsets of the days around the wall time, as JavaScript's Set keeps them.
    seen = new(globalThis.Set);
    times: list[float] = [];
    for day in [-1, 0, 1] {
        sample = new(globalThis.Date, wall + day * 86400000);
        zoned: float = globalThis.Date.prototype.getTime.call(zonedDateFields(sample, tz));
        sampled: float = globalThis.Date.prototype.getTime.call(sample);
        offset: float = zoned - sampled;
        if not globalThis.Set.prototype.has.call(seen, offset) {
            globalThis.Set.prototype.add.call(seen, offset);
            times.append(wall - offset);
        }
    }
    n: int = len(times);
    finite = True;
    for t in times {
        if globalThis.Number.isNaN(t) {
            finite = False;
        }
    }
    if finite {
        # Sorted in place by time (distinct offsets: no ties).
        k: int = 1;
        while k < n {
            t: float = times[k];
            j: int = k - 1;
            while j >= 0 and times[j] > t {
                times[j + 1] = times[j];
                j -= 1;
            }
            times[j + 1] = t;
            k += 1;
        }
    } else {
        dates = js_sort([new(globalThis.Date, t) for t in times], by_time);
        times = [globalThis.Date.prototype.getTime.call(d) for d in dates];
    }
    # The first candidate at the wall time, else the first after it, else the last.
    walls: list[float] = [];
    for t in times {
        w: float = wall_at(t, tz);
        if w == wall {
            return new(globalThis.Date, t);
        }
        walls.append(w);
    }
    for (i, t) in enumerate(times) {
        if walls[i] > wall {
            return new(globalThis.Date, t);
        }
    }
    return new(globalThis.Date, times[n - 1]);
}

def recentZonedDays(timeZone: any, count: any, now: any = None) -> list[any] {
    today = zonedDateFields(new(globalThis.Date) if now is None else now, timeZone);
    today.setUTCHours(0, 0, 0, 0);
    days = [];
    for i in range(globalThis.Array.from(record({"length": count})).length) {
        day = new(globalThis.Date, today);
        day.setUTCDate(day.getUTCDate() - globalThis.Number(count) + 1 + i);
        nxt = new(globalThis.Date, day);
        nxt.setUTCDate(nxt.getUTCDate() + 1);
        start = dateFromZonedFields(day, timeZone);
        end = dateFromZonedFields(nxt, timeZone);
        days.append(record({"date": day.toISOString().slice(0, 10), "start": start, "end": end}));
    }
    return days;
}
