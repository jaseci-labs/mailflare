glob DEFAULT_REPEAT_DAYS: list[int] = [1, 2, 3, 4, 5];

def:priv whole(value: any, low: int, high: int) -> bool {
    return globalThis.Number.isInteger(value) and low <= value <= high;
}

def normalizeCalendarRepeat(value: any = None) -> str {
    return value if value in ["daily", "weekly", "monthly", "weekdays", "yearly"] else "none";
}

"""Step between recurrences: an integer 1..999, else 1."""
def normalizeRepeatInterval(value: any = None) -> int {
    return value if whole(value, 1, 999) else 1;
}

"""Weekday of an nth-weekday monthly repeat (0-6), else null."""
def normalizeRepeatWeekday(value: any = None) -> any {
    return value if whole(value, 0, 6) else NULL;
}

"""Week of an nth-weekday monthly repeat (1-5, -1 = last), else null."""
def normalizeRepeatWeek(value: any = None) -> any {
    return value if whole(value, 1, 5) or value == -1 else NULL;
}

def normalizeCalendarRepeatDays(value: any = None) -> list[int] {
    if not globalThis.Array.isArray(value) {
        return [];
    }
    return sorted({day for day in value if whole(day, 0, 6)});
}

def:priv parsed_list(value: any) -> any {
    try {
        return globalThis.JSON.parse(either(value, "[]"));
    } except Exception {
        return [];
    }
}

def parseCalendarRepeatDays(value: any = None) -> list[int] {
    return normalizeCalendarRepeatDays(parsed_list(value));
}

def parseExcludedOccurrences(value: any = None) -> list[int] {
    parsed = parsed_list(value);
    if not globalThis.Array.isArray(parsed) {
        return [];
    }
    return [t for t in parsed if globalThis.Number.isSafeInteger(t) and t >= 0];
}

def parseCalendarOccurrenceId(value: str) -> any {
    separator = value.rfind("@");
    if separator < 1 {
        return NULL;
    }
    timestamp = globalThis.Number(value[separator + 1:]);
    if not globalThis.Number.isSafeInteger(timestamp) or timestamp < 0 {
        return NULL;
    }
    return {"seriesId": value[:separator], "startsAt": new(globalThis.Date, timestamp)};
}
