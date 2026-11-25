glob:priv TIME: any = rx(r"^([01]\d|2[0-3]):[0-5]\d$"),
          MARKS: any = rx(r"[̀-ͯ]", "g");

"""`rx_sub` whose result keeps JavaScript's string methods."""
def:priv sub(s: any, regex: any, to: str) -> any {
    return rx_sub(s, regex, to);
}

"""JavaScript's `typeof v === "object"` of a value that is not null (arrays included)."""
def:priv is_object(v: any) -> bool {
    return not nil(v)
        and globalThis.Object(v) is v
        and not globalThis.Function.prototype.isPrototypeOf(v);
}

def:priv whole(value: any, low: int, high: int) -> bool {
    return globalThis.Number.isInteger(value) and low <= value <= high;
}

def:priv distinct(values: any) -> bool {
    return new(globalThis.Set, values).size == len(values);
}

"""Lower-case ASCII of a text: accents are dropped with their marks."""
def:priv unaccented(value: any) -> any {
    return sub(value.normalize("NFKD"), MARKS, "").toLowerCase();
}

def slugifyBookingName(value: any) -> str {
    dashed = sub(sub(unaccented(value), rx("[^a-z0-9]+", "g"), "-"), rx("^-|-$", "g"), "");
    return sub(dashed.slice(0, 80), rx("-$"), "");
}

def isValidBookingSlug(value: any) -> bool {
    return 1 <= value.length <= 80 and rx("^[a-z0-9]+(?:-[a-z0-9]+)*$").test(value);
}

def normalizeBookingUsername(value: any = None) -> any {
    if not isinstance(value, str) {
        return NULL;
    }
    username = value.trim().toLowerCase();
    return username
        if 1 <= username.length <= 64
            and rx("^[a-z0-9._+-]+$").test(username)
            and rx("[a-z0-9]").test(username)
        else NULL;
}

def bookingUsernameFromEmail(email: str) -> str {
    candidate = sub(unaccented(email.split("@")[0]), rx("[^a-z0-9._+-]+", "g"), "-").slice(0, 56);
    return either(normalizeBookingUsername(candidate), "user");
}

def:priv is_range(v: any) -> bool {
    return is_object(v) and isinstance(v["startTime"], str) and isinstance(v["endTime"], str);
}

def parseBookingTimeRanges(value: any, fallback: any = None) -> list[any] {
    try {
        parsed = globalThis.JSON.parse(value);
        if globalThis.Array.isArray(parsed)
            and parsed.length
            and all([is_range(r) for r in parsed])
        {
            return parsed;
        }
    } except Exception {
        # Older rows use the single time window.
    }
    return [fallback] if fallback else [];
}

def:priv text_of(v: any) -> any {
    return v.trim() if isinstance(v, str) else "";
}

def:priv by_start(a: any, b: any) -> int {
    return a["startTime"].localeCompare(b["startTime"]);
}

def parseBookingEventInput(value: any = None) -> any {
    if not is_object(value) {
        return NULL;
    }
    name = text_of(value["name"]);
    slug: any = value["slug"].trim().toLowerCase()
        if isinstance(value["slug"], str)
        else slugifyBookingName(name);
    (description, location) = (text_of(value["description"]), text_of(value["location"]));
    (weekdays, duration) = (value["weekdays"], value["durationMinutes"]);
    hostIds = [] if value["hostIds"] is None else value["hostIds"];
    if not name
        or name.length > 120
        or not isValidBookingSlug(slug)
        or description.length > 2000
        or location.length > 240
        or not whole(duration, 5, 480)
    {
        return NULL;
    }
    if not globalThis.Array.isArray(hostIds)
        or hostIds.length > 20
        or not all([isinstance(id, str) and bool(id) for id in hostIds])
        or not distinct(hostIds)
    {
        return NULL;
    }
    if not globalThis.Array.isArray(weekdays)
        or not weekdays.length
        or not all([whole(day, 0, 6) for day in weekdays])
        or not distinct(weekdays)
    {
        return NULL;
    }
    (startTime, endTime) = (value["startTime"], value["endTime"]);
    timeRanges = either(
        value["timeRanges"],
        [record({"startTime": startTime, "endTime": endTime})]
            if isinstance(startTime, str) and isinstance(endTime, str)
            else NULL,
    );
    if not globalThis.Array.isArray(timeRanges) or not timeRanges.length or timeRanges.length > 12 {
        return NULL;
    }
    for r in timeRanges {
        if not is_range(r) or not TIME.test(r["startTime"]) or not TIME.test(r["endTime"]) {
            return NULL;
        }
        (opens, closes) = (timeToMinutes(r["startTime"]), timeToMinutes(r["endTime"]));
        if opens % 15 != 0 or closes % 15 != 0 or closes - opens < duration {
            return NULL;
        }
    }
    ranges = globalThis.Array.prototype.sort.call(timeRanges.slice(), by_start);
    for i in range(1, len(ranges)) {
        if ranges[i]["startTime"] < ranges[i - 1]["endTime"] {
            return NULL;
        }
    }
    (timeZone, enabled) = (value["timeZone"], value["enabled"]);
    if not isinstance(timeZone, str)
        or not isValidTimeZone(timeZone)
        or not (enabled is True or enabled is False)
    {
        return NULL;
    }
    return {
        "name": name,
        "slug": slug,
        "description": description,
        "color": normalizeCalendarColor(
            value["color"] if isinstance(value["color"], str) else None
        ),
        "hostIds": hostIds,
        "durationMinutes": duration,
        "location": location,
        "weekdays": sorted(weekdays),
        "startTime": ranges[0]["startTime"],
        "endTime": ranges[0]["endTime"],
        "timeRanges": ranges,
        "timeZone": timeZone,
        "enabled": enabled,
    };
}

def timeToMinutes(value: str) -> any {
    parts = value.split(":");
    minutes = globalThis.Number(parts[1]) if len(parts) > 1 else globalThis.NaN;
    return globalThis.Number(parts[0]) * 60 + minutes;
}

"""The slot of `event` that starts at a wall-clock date and time in the event's zone, or null when it offers none."""
def slotFromLocalDate(event: any, localDate: str, time: str) -> any {
    if not rx(r"^\d{4}-\d{2}-\d{2}$").test(localDate) or not TIME.test(time) {
        return NULL;
    }
    wall = new(globalThis.Date, f"{localDate}T{time}:00Z");
    if globalThis.Number.isNaN(wall.getTime())
        or wall.toISOString().slice(0, 10) != localDate
        or wall.getUTCDay() not in event["weekdays"]
    {
        return NULL;
    }
    minutes = timeToMinutes(time);
    duration = event["durationMinutes"];
    fits = [
        r
        for r in event["timeRanges"]
        if minutes >= timeToMinutes(r["startTime"])
            and minutes + duration <= timeToMinutes(r["endTime"])
    ];
    if not fits or minutes % 15 != 0 {
        return NULL;
    }
    zone = event["timeZone"];
    startsAt = dateFromZonedFields(wall, zone);
    if zonedDateFields(startsAt, zone).toISOString().slice(0, 16) != f"{localDate}T{time}" {
        return NULL;
    }
    return {
        "startsAt": startsAt,
        "endsAt": new(globalThis.Date, startsAt.getTime() + duration * 60000),
    };
}

def parseBookingWeekdays(value: any) -> list[int] {
    try {
        days = globalThis.JSON.parse(value);
        return [day for day in days if whole(day, 0, 6)] if globalThis.Array.isArray(days) else [];
    } except Exception {
        return [];
    }
}
