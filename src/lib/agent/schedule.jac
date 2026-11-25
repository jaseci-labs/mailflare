def parseAgentScheduledAt(value: any) -> any {
    ok = rx(r"^\d{4}-\d\d-\d\dT\d\d:\d\d(?::\d\d(?:\.\d{1,3})?)?(?:Z|[+-]\d\d:\d\d)$").test(value);
    late = "Scheduled time must be in the future";
    if value is not NULL and not (ok and globalThis.Date.parse(value) > globalThis.Date.now()) {
        raise new(globalThis.Error, late if ok else "Use a date and time with a timezone offset");
    }
    return NULL if value is NULL else new(globalThis.Date, value);
}
