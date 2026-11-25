glob DEFAULT_REPEAT_DAYS: list[int] = [1, 2, 3, 4, 5];

def normalizeCalendarRepeat(value: any = None) -> str {
    return value if value in "daily weekly monthly weekdays yearly".split() else "none";
}

def normalizeRepeatInterval(value: any = None) -> int {
    return value if whole(value, 1, 999) else 1;
}

def normalizeRepeatWeekday(value: any = None) -> any {
    return value if whole(value, 0, 6) else NULL;
}

def normalizeRepeatWeek(value: any = None) -> any {
    return value if whole(value, 1, 5) or value == -1 else NULL;
}

def normalizeCalendarRepeatDays(v: any = None) -> list[int] {
    return sorted({d for d in v if whole(d, 0, 6)}) if globalThis.Array.isArray(v) else [];
}

def:priv parsed(value: any) -> any {
    try {
        p = globalThis.JSON.parse(either(value, "[]"));
        return p if globalThis.Array.isArray(p) else [];
    } except Exception {
        return [];
    }
}

def parseCalendarRepeatDays(value: any = None) -> list[int] {
    return normalizeCalendarRepeatDays(parsed(value));
}

def parseExcludedOccurrences(value: any = None) -> list[int] {
    return [t for t in parsed(value) if globalThis.Number.isSafeInteger(t) and t >= 0];
}

def parseCalendarOccurrenceId(value: any) -> any {
    sep = value.lastIndexOf("@");
    ts = globalThis.Number(value.slice(sep + 1));
    if sep < 1 or not globalThis.Number.isSafeInteger(ts) or ts < 0 {
        return NULL;
    }
    return {"seriesId": value.slice(0, sep), "startsAt": new(globalThis.Date, ts)};
}
