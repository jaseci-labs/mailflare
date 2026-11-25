# Two disabled templates, (minutes, start, end), offered until the user has an event of their own.
glob:priv TEMPLATES: list[any] = [(30, "09:00", "11:00"), (15, "14:00", "16:00")],
          SLUGS: list[str] = ["30-minute-meeting", "15-minute-meeting"];

def visibleBookingEvents(events: any, userId: any, timeZone: any) -> any {
    have = [event.slug for event in events];
    if not userId or any(slug not in SLUGS for slug in have) {
        return events;
    }
    fixed = {"description": "", "location": "", "weekdays": "[1,2,3,4,5]", "enabled": False};
    owner = {"userId": userId, "timeZone": timeZone};
    hosts = globalThis.JSON.stringify([userId]);
    made: list[any] = [];
    for (m, start, end) in TEMPLATES {
        slug = f"{m}-minute-meeting";
        named = {"id": f"template:{m}-minute", "name": f"{m} Minute Meeting", "slug": slug};
        timed = {"durationMinutes": m, "startTime": start, "endTime": end, "isTemplate": True};
        ranges = globalThis.JSON.stringify([record({"startTime": start, "endTime": end})]);
        extra = {"color": DEFAULT_FOLDER_COLOR, "timeRanges": ranges, "hostIds": hosts};
        if slug not in have {
            made.append(merged(named, timed, fixed, owner, extra));
        }
    }
    return [*events, *made];
}
