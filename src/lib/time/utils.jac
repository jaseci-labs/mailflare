glob:priv FIELD_FORMATTERS: any = new(globalThis.Map),
          DISPLAY_FORMATTERS: any = new(globalThis.Map),
          NORMALIZED_ZONES: any = new(globalThis.Map),
          LOCAL_MINUTE: any = rx(r"^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$"),
          DateTimeFormat: any = globalThis.Intl.DateTimeFormat;

glob:priv resolved_user_zone: any = None;

"""A cache of at most 64 entries: it is emptied, not trimmed, when full."""
def:priv remember(cache: any, key: any, value: any) -> any {
    if cache.size >= 64 {
        cache.clear();
    }
    cache.set(key, value);
    return value;
}

def:priv field_formatter(timeZone: any) -> any {
    return FIELD_FORMATTERS.get(timeZone)
        or remember(
            FIELD_FORMATTERS,
            timeZone,
            new(
                DateTimeFormat,
                "en-US",
                record({
                    "timeZone": timeZone,
                    "year": "numeric",
                    "month": "2-digit",
                    "day": "2-digit",
                    "hour": "2-digit",
                    "minute": "2-digit",
                    "second": "2-digit",
                    "hourCycle": "h23",
                }),
            ),
        );
}

def:priv display_formatter(locale: any, options: any, timeZone: any) -> any {
    key = f"{either(locale, 'default')}\u0000{timeZone}\u0000{globalThis.JSON.stringify(options)}";
    return DISPLAY_FORMATTERS.get(key)
        or remember(
            DISPLAY_FORMATTERS,
            key,
            new(DateTimeFormat, locale, merged(options, {"timeZone": timeZone})),
        );
}

def normalizeTimeZone(value: any = None) -> str {
    key = value or "UTC";
    known = NORMALIZED_ZONES.get(key);
    if known {
        return known;
    }
    try {
        zone = new(DateTimeFormat, "en-US", record({"timeZone": key})).resolvedOptions().timeZone;
    } except Exception {
        zone = "UTC";
    }
    return remember(NORMALIZED_ZONES, key, zone);
}

def isValidTimeZone(value: any) -> bool {
    try {
        new(DateTimeFormat, "en-US", record({"timeZone": value}));
        return True;
    } except Exception {
        return False;
    }
}

def getUserTimeZone -> str {
    window = at(globalThis, "window");
    if window is None {
        return "UTC";
    }
    if resolved_user_zone {
        return resolved_user_zone;
    }
    zone = DateTimeFormat().resolvedOptions().timeZone or "UTC";
    try {
        saved = globalThis.JSON.parse(
            either(window.localStorage.getItem("mailflare-user-time-zone"), "null")
        );
        if not nil(saved)
            and isinstance(saved["timeZone"], str)
            and isValidTimeZone(saved["timeZone"])
        {
            zone = normalizeTimeZone(saved["timeZone"]);
        }
    } except Exception {
        # Device time remains available without storage.
    }
    resolved_user_zone = zone;
    return zone;
}

def clearUserTimeZoneCache {
    resolved_user_zone = None;
}

def getRequestTimeZone(request: any, preferredTimeZone: any = None) -> str {
    zone = preferredTimeZone;
    if nil(zone) {
        zone = new(globalThis.URL, request.url).searchParams.get("timeZone");
    }
    if nil(zone) {
        zone = request.headers.get("X-Time-Zone");
    }
    return normalizeTimeZone(zone);
}

"""The interface language the language provider keeps on `<html lang>`; the browser default when unset or on the server."""
def getDisplayLocale -> any {
    document = at(globalThis, "document");
    return None if document is None else (document.documentElement.lang or None);
}

def formatUserDate(value: any, options: any) -> str {
    zone = options["timeZone"] if isinstance(options["timeZone"], str) else getUserTimeZone();
    return display_formatter(getDisplayLocale(), options, zone).format(new(globalThis.Date, value));
}

def formatUserDateTimeLocal(value: any) -> str {
    return zonedDateFields(value, getUserTimeZone()).toISOString().slice(0, 16);
}

def:priv utc_date(
    year: any, month: any, day: any, hour: any, minute: any, second: any, ms: any
) -> any {
    made = new(globalThis.Date, 0);
    made.setUTCFullYear(
        globalThis.Number(year), globalThis.Number(month) - 1, globalThis.Number(day)
    );
    made.setUTCHours(
        globalThis.Number(hour), globalThis.Number(minute), globalThis.Number(second), ms
    );
    return made;
}

def parseUserDateTimeLocal(value: any) -> any {
    found = LOCAL_MINUTE.exec(value);
    if not found {
        return NULL;
    }
    fields = utc_date(found[1], found[2], found[3], found[4], found[5], 0, 0);
    if fields.toISOString().slice(0, 16) != value {
        return NULL;
    }
    return dateFromZonedFields(fields, getUserTimeZone());
}

"""A UTC date used only to do arithmetic on the timezone's wall-clock fields."""
def zonedDateFields(value: any, timeZone: any) -> any {
    f = {part["type"]: part.value for part in field_formatter(timeZone).formatToParts(value)};
    return utc_date(
        f.get("year"),
        f.get("month"),
        f.get("day"),
        f.get("hour"),
        f.get("minute"),
        f.get("second"),
        value.getUTCMilliseconds(),
    );
}

"""Use the earlier instant for repeated times and move forward across missing times."""
def dateFromZonedFields(fields: any, timeZone: any) -> any {
    wall = fields.getTime();
    offsets: list[any] = [];
    for day in [-1, 0, 1] {
        sample = new(globalThis.Date, wall + day * 86400000);
        offset = zonedDateFields(sample, timeZone).getTime() - sample.getTime();
        if offset not in offsets {
            offsets.append(offset);
        }
    }
    candidates = sorted(
        [new(globalThis.Date, wall - offset) for offset in offsets],
        key=lambda (d: any) -> any { d.getTime() },
    );
    walls = [zonedDateFields(d, timeZone).getTime() for d in candidates];
    for want_exact in [True, False] {
        for (i, w) in enumerate(walls) {
            if (w == wall) if want_exact else (w > wall) {
                return candidates[i];
            }
        }
    }
    return candidates[-1];
}

def recentZonedDays(timeZone: any, count: any, now: any = None) -> list[any] {
    today = zonedDateFields(new(globalThis.Date) if now is None else now, timeZone);
    today.setUTCHours(0, 0, 0, 0);
    days: list[any] = [];
    for index in range(max(0, globalThis.Math.trunc(count))) {
        day = new(globalThis.Date, today);
        day.setUTCDate(day.getUTCDate() - count + 1 + index);
        following = new(globalThis.Date, day);
        following.setUTCDate(following.getUTCDate() + 1);
        days.append(
            record({
                "date": day.toISOString().slice(0, 10),
                "start": dateFromZonedFields(day, timeZone),
                "end": dateFromZonedFields(following, timeZone),
            }),
        );
    }
    return days;
}
