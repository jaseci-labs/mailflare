glob IMPORT_JOBS_POLL_MS: int = 2000;

def isImportJobActive(job: any) -> bool {
    return job["status"] in ["queued", "running"];
}

"""Whole percent, or null while the job does not know its size yet."""
def getImportJobPercent(job: any) -> any {
    (M, total) = (globalThis.Math, job["total"]);
    if job["status"] == "completed" {
        return 100;
    }
    return NULL if total <= 0 else M.min(100, M.floor(job["processed"] / total * 100));
}
