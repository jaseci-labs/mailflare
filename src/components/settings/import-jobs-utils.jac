glob IMPORT_JOBS_POLL_MS: int = 2000;

def isImportJobActive(job: any) -> bool {
    return job["status"] in ["queued", "running"];
}

"""Whole percent, or null while the job does not know its size yet."""
def getImportJobPercent(job: any) -> any {
    # Number() coerces as JavaScript's `<=` and `/` do: a missing total or count gives NaN, not an error.
    (M, total, done) = (
        globalThis.Math,
        globalThis.Number(job["total"]),
        globalThis.Number(job["processed"]),
    );
    if job["status"] == "completed" {
        return 100;
    }
    return NULL if total <= 0 else M.min(100, M.floor(done / total * 100));
}
