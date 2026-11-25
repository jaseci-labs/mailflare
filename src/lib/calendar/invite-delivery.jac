"""Sends one message per attendee and returns the addresses that failed, so a saved event is never reported as a failed request."""
async def sendToAttendees(attendees: any, send: any) -> list[str] {
    results = await globalThis.Promise.allSettled(
        attendees.map(lambda (to: any) -> any { send(to) })
    );
    failed: list[str] = [];
    for (index, result) in enumerate(results) {
        if result.status != "rejected" {
            continue;
        }
        failed.append(attendees[index]);
        reason = result.reason;
        globalThis.console.warn(
            f"Calendar invitation to {attendees[index]} failed:",
            reason.message if globalThis.Error.prototype.isPrototypeOf(reason) else reason,
        );
    }
    return failed;
}
