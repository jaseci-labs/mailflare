glob:priv STAMP: any = rx(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,3})?)?(?:Z|[+-]\d{2}:\d{2})$"
);

def parseAgentScheduledAt(value: any) -> any {
    if value is NULL {
        return NULL;
    }
    if not STAMP.test(value) {
        raise new(globalThis.Error, "Use a date and time with a timezone offset");
    }
    date = new(globalThis.Date, value);
    if not globalThis.Number.isFinite(date.getTime()) or date.getTime() <= globalThis.Date.now() {
        raise new(globalThis.Error, "Scheduled time must be in the future");
    }
    return date;
}
