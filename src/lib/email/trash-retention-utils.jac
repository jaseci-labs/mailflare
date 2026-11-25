# Choices offered in Settings; any whole number in range is accepted by the API.
glob TRASH_RETENTION_OPTIONS: list[int] = [7, 14, 30, 60, 90],
     MIN_TRASH_RETENTION_DAYS: int = 1,
     MAX_TRASH_RETENTION_DAYS: int = 365;

# Messages purged per scheduled run, so one invocation stays well inside Worker limits.
glob TRASH_RETENTION_BATCH_SIZE: int = 200;

glob:priv DAY_MS: int = 24 * 60 * 60 * 1000;

"""Messages that entered Trash or Spam before this instant are due for deletion."""
def getTrashRetentionCutoff(now: any, days: any) -> any {
    return new(globalThis.Date, now.getTime() - days * DAY_MS);
}

"""Null (or anything outside the supported range) means "never delete automatically"."""
def normalizeTrashRetentionDays(value: any) -> any {
    in_range = globalThis.Number.isInteger(value)
        and MIN_TRASH_RETENTION_DAYS <= value <= MAX_TRASH_RETENTION_DAYS;
    return value if in_range else NULL;
}

def describeTrashRetention(days: any, t: any = None) -> str {
    translate = defaultTranslator if t is None else t;
    return translate("settings.trash.afterDay", {"count": days})
        if days
        else translate("settings.trash.never");
}
