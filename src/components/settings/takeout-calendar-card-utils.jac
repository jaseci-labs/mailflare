glob:priv STEPS: dict[str, int] = {"ArrowRight": 1, "ArrowDown": 1, "ArrowLeft": -1, "ArrowUp": -1};

"""The radio to select for an arrow, Home or End key, wrapping at both ends; null for any other key."""
def radioTarget(key: any, index: any, count: any) -> any {
    step = STEPS.get(key);
    if step is None {
        return {"Home": 0, "End": count - 1}.get(key, NULL);
    }
    return (index + step + count) % count if count else globalThis.NaN;  # JavaScript's `% 0` is NaN
}

""""failed" when nothing worked, "partial" when something failed or the run was stopped or limited, else "success"."""
def resultTone(results: any) -> str {
    rs = [(r["mode"], r["summary"]) for r in results];
    # An import fills `events` with the whole file, whatever happened to it.
    worked = sum([s["imported"] + s["skipped"] if m == "import" else s["events"] for (m, s) in rs]);
    problem = any([s["failed"] > 0 or s["aborted"] or s["rateLimited"] for (_, s) in rs]);
    return ("failed" if worked == 0 else "partial") if problem else "success";
}
