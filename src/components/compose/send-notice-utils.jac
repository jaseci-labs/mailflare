# A scheduled toast carries a cancel action and a sent one a link, so both outlast the 3.2s default;
# DELIVERY_WAIT_MS is how long the toast waits for the queue to report delivery or failure.
glob SCHEDULED_NOTICE_MS: int = 8000,
     SENT_NOTICE_MS: int = 8000,
     DELIVERY_WAIT_MS: int = 30000;
type SendResult = any;
type SendNoticeParts = any;

"""Splits a template, its `{subject}` and `{seconds}` placeholders intact, so the subject can be a
link and only the ticking suffix changes while the toast is live."""
def splitSendTemplate(template: str, countdown: bool) -> any {
    (before, _, rest) = template.partition("{subject}");
    (after, found, tail) = rest.partition("{seconds}");
    if not countdown or not found {
        return {"before": before, "after": rest};
    }
    return {
        "before": before,
        "after": after,
        "ticker": lambda (s: any) -> str { globalThis.String(s) + tail },
    };
}

"""Picks the toast a send response deserves. The server reports the undo window as a duration, so a
clock difference between server and browser cannot shorten or stretch the countdown."""
def resolveSendNotice(result: any, now: any = None) -> any {
    (id, secs, N) = (result["messageId"], result["undoSeconds"], globalThis.Number);
    now = globalThis.Date.now() if now is None else now;
    if id and num_or(secs, 0) {
        left = result["undoRemainingMs"];
        ms = globalThis.Math.max(0, left if N.isFinite(left) else N(secs) * 1000);
        # No time left means the queue may already be sending: watch for the result, do not guess.
        plan = {"kind": "undo", "endAt": N(now) + ms, "durationMs": ms}
            if ms > 0
            else {"kind": "sending"};
        return {**plan, "messageId": id};
    }
    if id and result["scheduled"] {
        return {
            "kind": "scheduled",
            "messageId": id,
            "scheduledAt": either(result["scheduledAt"], NULL),
        };
    }
    return {"kind": "sent"};
}
