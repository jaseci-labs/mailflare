glob ACCOUNT_RESTORE_DAYS: int = 20;

glob:priv RESTORE_MS: int = ACCOUNT_RESTORE_DAYS * 24 * 60 * 60000;

"""Last moment a deleted account can still be restored."""
def getAccountPurgeDate(deletedAt: any) -> any {
    return new(globalThis.Date, deletedAt.getTime() + RESTORE_MS);
}

"""Cutoff for the scheduled purge: accounts deleted at or before this are removed for good."""
def getAccountPurgeCutoff(now: any) -> any {
    return new(globalThis.Date, now.getTime() - RESTORE_MS);
}

def getAccountStatus(account: any) -> str {
    if at(account, "deletedAt") {
        return "pendingDeletion";
    }
    return "disabled" if account["disabled"] else "active";
}
