# Above this many files an import can reach the daily limits of Cloudflare's free plan (each file takes a
# few requests and database rows), so the card warns and offers to import one folder at a time.
glob LARGE_IMPORT_FILES: int = 5000;

"""The folder to import from without asking: the one called Drive, or the only one; else "" (the user picks)."""
def defaultDriveRoot(roots: any) -> any {
    key = dig(first([r for r in roots if r["label"].toLowerCase() == "drive"]), ["key"]);
    return either(key, roots[0]["key"] if len(roots) == 1 else "");
}

"""`Google Drive (2026-11-21)`, from the local date."""
def newFolderName(now: any) -> str {
    (m, d) = (globalThis.String(now.getMonth() + 1), globalThis.String(now.getDate()));
    return f"Google Drive ({now.getFullYear()}-{m.padStart(2, '0')}-{d.padStart(2, '0')})";
}

"""The user's folders labelled with their path ("Docs / Taxes"), sorted by it. A cycle or a missing parent ends the path."""
def folderOptions(folders: any) -> any {
    by_id = new(globalThis.Map, [[f["id"], f] for f in folders]);
    def label(id: any) -> str {
        (ids, cur) = ([], by_id.get(id));
        while cur and cur["id"] not in ids and len(ids) < 64 {
            nxt = by_id.get(cur["parentId"]) if cur["parentId"] else None;
            (ids, cur) = ([cur["id"], *ids], nxt);
        }
        return " / ".join([by_id.get(i)["name"] for i in ids]);
    }
    out = [{"id": f["id"], "label": label(f["id"])} for f in folders];
    return js_sort(out, lambda (a: any, b: any) -> any { a["label"].localeCompare(b["label"]) });
}

"""Free Drive storage in bytes, or null when there is no limit (or it is not known)."""
def freeStorage(used: any, limit: any) -> any {
    # typeof "number": Number(v) is v for every number but NaN.
    nums = all([globalThis.Number(v) is v or globalThis.Number.isNaN(v) for v in [used, limit]]);
    return globalThis.Math.max(0, limit - used) if nums else NULL;
}

""""failed" when nothing got in (or storage was full before anything did), "partial" when something went wrong along the way, else "success"."""
def driveTone(s: any) -> str {
    problem = s["failed"] > 0 or s["aborted"] or s["storageFull"] or s["stoppedAfterFailures"];
    return ("failed" if s["imported"] + s["skipped"] == 0 else "partial") if problem else "success";
}

def isLargeImport(files: any) -> bool {
    return files > LARGE_IMPORT_FILES;
}

"""The folders at the top of the chosen Takeout folder with how many files each holds, by name. Loose files at the top are in none."""
def topFolders(files: any) -> any {
    tops = [f["segments"][0] for f in files if len(f["segments"]) > 1];
    out = [{"name": n, "files": tops.count(n)} for n in [*new(globalThis.Set, tops)]];
    return js_sort(out, lambda (a: any, b: any) -> any { a["name"].localeCompare(b["name"]) });
}

"""Import needs a chosen Takeout folder that was not cut short (another folder of the export being cut short does not matter), with files, and no run going."""
def canStartDrive(files: any, running: any, folder: any) -> bool {
    return files > 0 and not running and bool(folder) and not folder["tooMany"];
}
