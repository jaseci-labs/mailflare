# One message per attendee; returns the addresses that failed, so a saved event is never reported as a failed request.
async def sendToAttendees(people: any, send: any) -> list[str] {
    results = await globalThis.Promise.allSettled(people.map(lambda (to: any) -> any { send(to) }));
    failed = [(people[i], r.reason) for (i, r) in enumerate(results) if r.status == "rejected"];
    for (to, why) in failed {
        reason = why.message if globalThis.Error.prototype.isPrototypeOf(why) else why;
        globalThis.console.warn(f"Calendar invitation to {to} failed:", reason);
    }
    return [to for (to, _) in failed];
}
