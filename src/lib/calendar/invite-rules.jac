type InboundInvitePlan = any;

type InviteAnswerPlan = any;

"""The form `invite_sender` is stored in: the bare address, lower case."""
def normalizeInviteSender(address: any = None) -> str {
    bare: any = getEmailAddress(either(address, ""));
    return bare.trim().toLowerCase();
}

"""
Whether `senderAddress` may change an existing invitation event: only the sender stored in `inviteSender` when the
row was created. A row without one has no known sender and is never changed by mail (fails closed).
"""
def inviteSenderMatches(existing: any, senderAddress: str) -> bool {
    sender = normalizeInviteSender(senderAddress);
    stored = at(existing, "inviteSender");
    return bool(sender) and bool(stored) and normalizeInviteSender(stored) == sender;
}

"""
The recipient's zone for reading all-day, floating and unresolvable-TZID times: the account's saved zone, else the
zone of their most recently updated calendar event that has one, else null (unknown). Invalid names are skipped.
"""
def chooseRecipientZone(userZone: any = None, latestEventZone: any = None) -> any {
    for zone in [userZone, latestEventZone] {
        if zone and isValidTimeZone(zone) {
            return normalizeTimeZone(zone);
        }
    }
    return NULL;
}

"""
True when an inbound invitation cannot be applied without knowing the recipient's zone: some time in it was read in
the fallback zone. Cancelling a whole series and recording a reply use no times, so they never need it.
"""
def inboundNeedsRecipientZone(invite: any) -> bool {
    method = at(invite, "method");
    if not at(invite, "usedFallbackZone") or method == "REPLY" {
        return False;
    }
    return not (method == "CANCEL" and not at(invite, "recurrenceId"));
}

"""Adds one occurrence start (epoch ms, the unit expandCalendarEvents compares) to an excluded_occurrences JSON array."""
def addExcludedOccurrence(excludedOccurrences: any, occurrence: any) -> str {
    excluded = parseExcludedOccurrences(either(excludedOccurrences, "[]"));
    ms = occurrence.getTime();
    return globalThis.JSON.stringify(excluded if ms in excluded else sorted(excluded + [ms]));
}

"""Existing exclusions plus the invitation's EXDATEs, so refreshing a series never brings a cancelled occurrence back."""
def mergeExcludedOccurrences(excludedOccurrences: any, dates: any) -> str {
    excluded = parseExcludedOccurrences(either(excludedOccurrences, "[]"));
    return globalThis.JSON.stringify(sorted(set(excluded + [date.getTime() for date in dates])));
}

"""Anything older than the stored revision (lower SEQUENCE) arrived out of order."""
def:priv stale(invite: any, existing: any) -> bool {
    stored = at(existing, "inviteSequence");
    return not nil(stored) and invite["sequence"] < stored;
}

"""
What an incoming REQUEST or CANCEL does to the recipient's calendar, once the sender check has passed.
A cancel of one occurrence excludes it; a request about one occurrence upserts an override for it.
Anything older than the stored revision (lower SEQUENCE) arrived out of order and is ignored.
"""
def planInboundInvite(invite: any, existing: any = None) -> dict[str, any] {
    (method, occurrence) = (at(invite, "method"), at(invite, "recurrenceId"));
    if method not in ["CANCEL", "REQUEST"] {
        return {"action": "ignore", "reason": "method"};
    }
    if not existing {
        return {"action": "insert"}
            if method == "REQUEST" and not occurrence
            else {"action": "ignore", "reason": "no event"};
    }
    if stale(invite, existing) {
        return {"action": "ignore", "reason": "stale"};
    }
    if occurrence {
        return {
            "action": "exclude" if method == "CANCEL" else "upsert-override",
            "occurrence": occurrence,
        };
    }
    return {"action": "delete" if method == "CANCEL" else "update"};
}

"""
What answering an invitation from the message (Accept, Maybe, Decline, or Remove on a cancellation) does to the
calendar. One occurrence: Decline or a cancel excludes it, Accept and Maybe upsert an override for it. The whole
series: Decline or a cancel deletes it; Accept and Maybe write the invitation, or only the answer when the calendar
already holds a newer revision (higher SEQUENCE) than this message.
"""
def planInviteAnswer(invite: any, response: str, existing: any = None) -> dict[str, any] {
    removing = at(invite, "method") == "CANCEL" or response == "declined";
    occurrence = at(invite, "recurrenceId");
    stored = at(existing, "inviteSequence") if existing else None;
    # The calendar already holds a newer revision of this series: record the answer without reverting it.
    newer = not nil(stored) and stored > invite["sequence"];
    if occurrence {
        if not existing {
            return {"action": "none"};
        }
        if removing {
            return {"action": "exclude", "occurrence": occurrence};
        }
        return {"action": "status"}
            if newer
            else {"action": "upsert-override", "occurrence": occurrence};
    }
    if removing {
        return {"action": "delete"} if existing else {"action": "none"};
    }
    return {"action": "status" if newer else "upsert"};
}
