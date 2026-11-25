def agentTimeContext(timeZone: any = None) -> str {
    (now, zone, F) = (new(globalThis.Date), "UTC", globalThis.Intl.DateTimeFormat);
    try {
        new(F, "en-US", record({"timeZone": timeZone or zone})).format(now);
        zone = timeZone or zone;
    } except Exception {}
    o = record({"timeZone": zone, "dateStyle": "full", "timeStyle": "long"});
    return f"Current UTC time: {now.toISOString()}. User timezone: {zone}. Current user time: {new(F, 'en-US', o).format(now)}.";
}
