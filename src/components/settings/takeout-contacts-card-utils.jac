""""failed" when nothing worked, "partial" when something failed or the run was stopped or limited, else "success"."""
def contactsTone(results: any) -> str {
    runs = [(r["mode"], r["summary"]) for r in results];
    # A preview works on the whole file; an import counts what the server took.
    worked = sum([
        s["created"] + s["updated"] + s["unchanged"] if m == "import" else s["withEmail"]
        for (m, s) in runs
    ]);
    problem = any([
        s["failed"] > 0 or s["photosFailed"] > 0 or s["aborted"] or s["rateLimited"]
        for (_, s) in runs
    ]);
    return ("failed" if worked == 0 else "partial") if problem else "success";
}

"""Only the owner of an address book may import into it: the server answers 404 to a delegate of a shared
mailbox, even with full access. When the owner or the user is not known yet, the server decides."""
def isAddressBookOwner(mailbox: any, userId: any) -> bool {
    owner = dig(mailbox, ["userId"]);
    return not owner or not userId or owner == userId;
}
