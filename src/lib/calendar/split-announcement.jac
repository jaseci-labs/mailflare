# The stored row values of one side of the split that its file is built from. `repeatUntil` is the exclusive
# end of the series, written as the RRULE UNTIL verbatim like the series writer does everywhere; Mailflare's
# own parser re-adds its one-second inclusive pad on read.
glob:priv SIDE_FIELDS: list[str] = """title description location startsAt endsAt uid sequence reminderMinutes repeat
    repeatDays repeatAnchorDay repeatUntil repeatInterval repeatWeekday repeatWeek excludedOccurrences overrides""".split();

# Guest announcement for a "this and following" split: two files, because the truncation and the fork are
# different series under different UIDs. (1) The truncation under the ORIGINAL uid: the ORIGINAL DTSTART with
# the full repeat context, UNTIL at the split, the EXDATEs and the pre-split overrides. The original DTSTART must
# stay first: the fork's later DTSTART with UNTIL at the split would describe an empty recurrence set.
# (2) An invitation under the FORK's uid: the fork times as a new series with its own repeat context.
def buildSplitAnnouncement(args: any) -> any {
    def file_for(side: any) -> any {
        fields = {k: side[k] for k in SIDE_FIELDS};
        return createCalendarInvitation(
            merged(fields, {"organizer": args["organizer"], "attendees": args["attendees"]})
        );
    }
    return {"truncationFile": file_for(args["original"]), "forkFile": file_for(args["fork"])};
}
