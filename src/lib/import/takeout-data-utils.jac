"""Caps on each whole-read text source (.ics, .vcf, .csv) and on Drive files (and folders) per product folder."""
glob MAX_TEXT_SOURCE_BYTES: int = 64 * 1024 * 1024,
     MAX_DRIVE_FILES: int = 200000;

# PEEK fits the longest Google contacts header; `plus` adds Zip64 sizes past Jac's 2**53 int limit.
glob:priv SHOWN: int = 20,
          PEEK: int = 64 * 1024,
          js: any = globalThis.String,
          plus: any = lambda (a: float, b: float) -> float { a + b },
          split: any = globalThis.String.prototype.split,
          SLASH: any = rx(r"[\\/]"),
          JUNK: any = rx(r"^(\.DS_Store|Thumbs\.db|desktop\.ini|\._.*)$", "i"),
          SIDECAR: any = rx(r"\.(json|mbox)$", "i"),
          EMPTY: str = """{"calendars": [], "contacts": [], "tooLarge": [], "ignored": [], "unreadable": [],
          "drive": {"roots": [], "files": [], "dirs": [], "skipped": {"symlinks": 0, "encrypted": 0},
          "rejected": [], "rejectedCount": 0}}""";

"""The first bytes of a file or zip entry; a deflated entry is cut off after them, not inflated."""
async def:priv peek(file: any, entry_: any) -> any {
    if globalThis.Boolean(entry_) {
        (reader, parts, total) = ((await openZipEntry(file, entry_)).getReader(), [], 0);
        try {
            step = await reader.read();
            while not step.done {
                parts.append(step.value);
                total += step.value.length;
                step = await reader.read() if total < PEEK else record({"done": True});
            }
        } finally {
            await reader.cancel().catch(lambda (e: any) -> any { None });
        }
        file = new(globalThis.Blob, parts);
    }
    return new(globalThis.Uint8Array, await file.slice(0, PEEK).arrayBuffer());
}

"""Whether a .csv is a Google contacts export: its first row has a name and an e-mail value column."""
async def:priv google_csv(file: any, entry_: any) -> bool {
    try {
        rows = parseCsv(decodeContactsCsv(await peek(file, entry_)), {"maxRows": 1})["rows"];
        return isGoogleContactsHeader(either(first(rows), []));
    } except Exception {
        return False;
    }
}

"""The product folder of an entry: `Takeout/<product>` or, re-zipped, the first folder; null for a top-level file."""
def:priv root_of(name: any) -> any {
    parts = [p for p in split.call(name, SLASH) if p != "" and p != "."];
    (n, k) = (len(parts), 2 if first(parts) == "Takeout" else 1);
    return parts[:k] if n > k or (n == k and name.endsWith("/")) else NULL;
}

"""Finds calendars, contacts (.vcf, Google .csv) and Drive files (of `Drive` and other product folders) in
files and Takeout zips by extension (folder names are localized); entry names never become paths."""
async def scanTakeoutData(files: any, opts: any = None) -> any {
    limit = MAX_DRIVE_FILES if opts is None else either(opts["maxDriveFiles"], MAX_DRIVE_FILES);
    (scan, roots, dirs) = (globalThis.JSON.parse(EMPTY), {}, {});
    async def found(file: any, ent: any, name: any, size: any) -> bool {
        ext = sub(name, rx(r"^.*\.(ics|vcf|csv)$|^.*$", "is"), "$1").toLowerCase();
        if not ext or (ext == "csv" and not await google_csv(file, ent)) {
            return False;
        }
        big = size > MAX_TEXT_SOURCE_BYTES;
        (scan.tooLarge if big else []).push(name);
        n = len(scan.calendars) + len(scan.contacts);
        id = f"{n}:{js(file.name)}:{js(dig(ent, ['name'], ''))}";
        label = rx_sub(name, rx(r"\.[^.]*$"), "");
        kind: dict[str, str] = {} if ext == "ics" else {"kind": "vcard" if ext == "vcf" else "csv"};
        source = {"id": id, "label": label, "size": size, "file": file, "entry": ent};
        target = [] if big else scan["calendars" if ext == "ics" else "contacts"];
        target.push(merged(source, kind));
        return True;
    }
    def add_drive(file: any, ent: any, prefix: list[any]) {
        (key, path) = ("/".join(prefix), takeoutDrivePath(ent.name, prefix));
        (segments, folder) = (either(at(path, "segments"), []), at(path, "directory"));
        if owns(path, "error") {
            scan.drive.rejectedCount += 1;
            # A hostile zip could hold hundreds of thousands of bad names; only the first few are kept.
            bad = record({"name": ent.name, "reason": path["error"]});
            (scan.drive.rejected if len(scan.drive.rejected) < SHOWN else []).push(bad);
        } elif folder and len(segments) > 0 and dirs.get(key, 0) < limit {
            dirs[key] = dirs.get(key, 0) + 1;
            scan.drive.dirs.push(record({"rootKey": key, "segments": segments}));
        } elif not folder and len(segments) > 0 {
            fields = {"key": key, "prefix": prefix, "label": prefix[len(prefix) - 1], "files": 0};
            rt = roots.setdefault(key, record({**fields, "bytes": 0, "tooMany": False}));
            rt.tooMany = rt.tooMany or rt.files >= limit;
            if rt.files < limit {
                named = {"rootKey": key, "segments": segments, "name": segments[len(segments) - 1]};
                info = {"size": ent.size, "crc32": ent.crc32, "file": file, "entry": ent};
                scan.drive.files.push(merged(named, info));
                (rt.files, rt.bytes) = (rt.files + 1, plus(rt.bytes, ent.size));
            }
        }
    }
    for file in files {
        zip = rx(r"\.zip$", "i").test(file.name);
        missed = not zip and not await found(file, NULL, file.name, file.size);
        (scan.ignored if missed else []).push(file.name);
        entries = await listZipEntries(file).catch(lambda (e: any) -> any { NULL }) if zip else [];
        (scan.unreadable if nil(entries) else []).push(file.name);
        for ent in either(entries, []) {
            name = split.call(ent.name, SLASH).pop();
            if rx(r"^__MACOSX\/").test(ent.name) or JUNK.test(name) {
                continue;
            }
            prefix = root_of(ent.name);
            in_drive = not nil(prefix) and prefix[len(prefix) - 1].toLowerCase() == "drive";
            folder = bool(ent.name.endsWith("/"));
            # Symlinks and encrypted entries never carry usable data; those in Drive are counted.
            unusable = not folder and bool(ent.isSymlink or ent.encrypted);
            hid = folder or unusable or name.startsWith(".");
            # Mail and JSON sidecars are not Drive files.
            other = not nil(prefix) and not SIDECAR.test(name);
            if unusable and in_drive {
                scan.drive.skipped["symlinks" if ent.isSymlink else "encrypted"] += 1;
            } elif in_drive or (not (hid or await found(file, ent, name, ent.size)) and other) {
                add_drive(file, ent, prefix);
            }
        }
    }
    scan.drive.roots = list(roots.values());
    return scan;
}

async def readTakeoutSource(source: any) -> any {
    if globalThis.Boolean(source["entry"]) {
        return await readZipEntryBytes(source["file"], source["entry"], MAX_TEXT_SOURCE_BYTES);
    }
    if globalThis.Number(source["size"]) > MAX_TEXT_SOURCE_BYTES {
        raise new(globalThis.Error, js(source["label"]) + " is too large");
    }
    return new(globalThis.Uint8Array, await source["file"].arrayBuffer());
}
