glob:priv FIELDS: any = new(globalThis.Map),
          DISPLAY: any = new(globalThis.Map),
          ZONES: any = new(globalThis.Map),
          DTF: any = globalThis.Intl.DateTimeFormat,
          TWO_DIGITS: any = {k: "2-digit" for k in "month day hour minute second".split()},
          FIELD_KEYS: list[str] = "year month day hour minute second".split(),
          user_zone: any = None;

# A cache of at most 64 entries is emptied, not trimmed, when full.
def:priv cached(cache: any, key: any, make: any) -> any {
    if not cache.get(key) {
        if cache.size >= 64 {
            cache.clear();
        }
        cache.set(key, make());
    }
    return cache.get(key);
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
    return cached(ZONES, key, lambda -> any { either(zone_of(key), "UTC") });
}

def isValidTimeZone(value: any) -> bool {
    return not nil(zone_of(value));
}

def getUserTimeZone -> str {
    window = at(globalThis, "window");
    if window is None or user_zone {
        return "UTC" if window is None else user_zone;
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
    document = at(globalThis, "document");
    return None if document is None else (document.documentElement.lang or None);
}

def formatUserDate(value: any, options: any) -> str {
    tz = options["timeZone"] if isinstance(options["timeZone"], str) else getUserTimeZone();
    locale = getDisplayLocale();
    key = f"{either(locale, 'default')}\u0000{tz}\u0000{globalThis.JSON.stringify(options)}";
    make = lambda -> any { new(DTF, locale, merged(options, {"timeZone": tz})) };
    return cached(DISPLAY, key, make).format(new(globalThis.Date, value));
}

def formatUserDateTimeLocal(value: any) -> str {
    return zonedDateFields(value, getUserTimeZone()).toISOString().slice(0, 16);
}

# A UTC date of [year, month, day, hour, minute, second] (numbers or digit strings) and milliseconds.
def:priv utc(p: list[any], ms: any) -> any {
    (d, n) = (new(globalThis.Date, 0), [globalThis.Number(x) for x in p]);
    d.setUTCFullYear(n[0], n[1] - 1, n[2]);
    d.setUTCHours(n[3], n[4], n[5], ms);
    return d;
}

def parseUserDateTimeLocal(value: any) -> any {
    m = rx(r"^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$").exec(value);
    fields = utc([m[1], m[2], m[3], m[4], m[5], 0], 0) if m else NULL;
    if not m or fields.toISOString().slice(0, 16) != value {
        return NULL;
    }
    return dateFromZonedFields(fields, getUserTimeZone());
}

"""A UTC date used only to do arithmetic on the timezone's wall-clock fields."""
def zonedDateFields(value: any, timeZone: any) -> any {
    options = merged({"timeZone": timeZone, "year": "numeric", "hourCycle": "h23"}, TWO_DIGITS);
    dtf = cached(FIELDS, timeZone, lambda -> any { new(DTF, "en-US", options) });
    f = {p["type"]: p["value"] for p in dtf.formatToParts(value)};
    return utc([f.get(k) for k in FIELD_KEYS], value.getUTCMilliseconds());
}

"""Use the earlier instant for repeated times and move forward across missing times."""
def dateFromZonedFields(fields: any, tz: any) -> any {
    (wall, D) = (fields.getTime(), globalThis.Date);
    samples = [new(D, wall + k * 86400000) for k in [-1, 0, 1]];
    cands = [new(D, wall - zonedDateFields(s, tz).getTime() + s.getTime()) for s in samples];
    cands = sorted(cands, key=lambda (d: any) -> any { d.getTime() });
    walls = [zonedDateFields(d, tz).getTime() for d in cands];
    hits = [c for (i, c) in enumerate(cands) if walls[i] == wall];
    hits += [c for (i, c) in enumerate(cands) if walls[i] > wall];
    return hits[0] if hits else cands[-1];
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
        (start, end) = (dateFromZonedFields(day, timeZone), dateFromZonedFields(nxt, timeZone));
        days.append(record({"date": day.toISOString().slice(0, 10), "start": start, "end": end}));
    }
    return days;
}
