def:priv formatter(zone: str, style: dict[str, any] = {}) -> any {
    return new(globalThis.Intl.DateTimeFormat, "en-US", record({"timeZone": zone, **style}));
}

def agentTimeContext(timeZone: any = None) -> str {
    now = new(globalThis.Date);
    zone = "UTC";
    if timeZone {
        try {
            formatter(timeZone).format(now);
            zone = timeZone;
        } except Exception {
            # An invalid timezone falls back to UTC.
            zone = "UTC";
        }
    }
    local = formatter(zone, {"dateStyle": "full", "timeStyle": "long"}).format(now);
    return f"Current UTC time: {now.toISOString()}. User timezone: {zone}. Current user time: {local}.";
}
