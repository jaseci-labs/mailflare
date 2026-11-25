import from "drizzle-orm" { sql }

glob:priv COLUMNS: list[str] = [
    "id",
    "user_id",
    "mailbox_id",
    "title",
    "description",
    "location",
    "attendees",
    "color",
    "repeat",
    "repeat_days",
    "excluded_occurrences",
    "time_zone",
    "starts_at",
    "ends_at",
    "created_at",
    "updated_at",
];

"""A SQL fragment: `text` with each `?` bound to the next of `values` (a parameter, or another fragment)."""
def:priv q(text: str, *values: any) -> any {
    return sql(text.split("?"), *values);
}

def:priv seconds(ms: any) -> int {
    return globalThis.Math.floor(ms / 1000);
}

"""
Inserts one calendar event per host, but only when none of the hosts is busy, in a single statement so two
guests cannot take the same slot. Unanswered invitations (response_status needs-action) do not block, matching
availableBookingSlots, so every offered slot can be booked. Returns whether every host was booked.
"""
async def createBookedCalendarEvents(
    env: any,
    event: any,
    guestName: str,
    guestEmail: str,
    startsAt: any,
    endsAt: any,
    guestEmails: any = None,
    notes: any = None,
) -> bool {
    guestEmails = [] if guestEmails is None else guestEmails;
    notes = "" if notes is None else notes;
    hostIds = event["hostIds"];
    startSeconds = seconds(new(globalThis.Date, startsAt).getTime());
    endSeconds = seconds(new(globalThis.Date, endsAt).getTime());
    nowSeconds = seconds(globalThis.Date.now());
    requested = sql.join(
        [q("select ? as host_id, ? as event_id", id, newId("evt")) for id in hostIds],
        q(" union all "),
    );
    hostList = sql.join([q("?", id) for id in hostIds], q(", "));
    columns = sql.join([sql.identifier(name) for name in COLUMNS], q(", "));
    description = "\n\n".join([
        part
        for part in [f"Booked by {guestName} ({guestEmail})", notes]
        if part
    ]);
    busy = lambda (name: str) -> any { sql.identifier(name) };
    result = await getDb(env).run(
        q(
            "insert into ? (?)\n\t\tselect requested_hosts.event_id, requested_hosts.host_id, null, ?, ?, ?,\n"
                + "\t\t\t?, ?, 'none', '[]', '[]', ?, ?, ?, ?, ?\n"
                + "\t\tfrom (?) requested_hosts\n"
                + "\t\twhere (select count(*) from ? busy where busy.? in (?) and busy.? = 'none'\n"
                + "\t\t\tand (busy.? is null or busy.? <> 'needs-action')\n"
                + "\t\t\tand busy.? < ? and busy.? > ?) = 0",
            calendarEvents,
            columns,
            f"{event['name']} with {guestName}",
            description,
            event["location"],
            globalThis.JSON.stringify([guestEmail, *guestEmails]),
            event["color"],
            event["timeZone"],
            startSeconds,
            endSeconds,
            nowSeconds,
            nowSeconds,
            requested,
            calendarEvents,
            busy("user_id"),
            hostList,
            busy("repeat"),
            busy("response_status"),
            busy("response_status"),
            busy("starts_at"),
            endSeconds,
            busy("ends_at"),
            startSeconds,
        ),
    );
    return result.meta.changes == hostIds.length;
}
