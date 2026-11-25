"""`k=v` pairs; `~` and `^` abbreviate the Office and OpenDocument type prefixes."""
def:priv table(text: str) -> any {
    text = text.replace("~", "application/vnd.openxmlformats-officedocument.");
    text = text.replace("^", "application/vnd.oasis.opendocument.");
    return record({k: v for (k, _, v) in [p.partition("=") for p in text.split()]});
}

# Controls, bidi embeddings, overrides and isolates, zero-width characters: they disguise names.
glob:priv HIDDEN: str = "\\0-\\x1f\\x7f-\\x9f\\u200b-\\u200d\\u202a-\\u202e\\u2066-\\u2069\\ufeff",
          INVISIBLE: any = rx(f"[{HIDDEN}]", "g"),
          OPAQUE: str = "application/octet-stream";

# Extension to content type. Anything not listed, HTML, SVG and XML included, is stored as opaque bytes.
glob:priv TYPES: any = table("""pdf=application/pdf png=image/png jpg=image/jpeg jpeg=image/jpeg
    gif=image/gif webp=image/webp txt=text/plain csv=text/csv json=application/json
    docx=~wordprocessingml.document xlsx=~spreadsheetml.sheet pptx=~presentationml.presentation
    odt=^text ods=^spreadsheet odp=^presentation zip=application/zip mp3=audio/mpeg mp4=video/mp4""");

# First bytes (hex) each binary type must start with; WebP also has "WEBP" at 8. Office files are zips.
glob:priv MAGIC: any = table("""application/pdf=25504446 image/png=89504e47 image/jpeg=ffd8ff
    image/gif=47494638 image/webp=52494646""");

# The import card matches the first; the second bounds the folders (ancestors counted) of one request.
glob NESTED_TOO_DEEPLY: str = "Folders are nested too deeply",
     MAX_IMPORT_FOLDERS: int = 64;

def:priv visible(value: any) -> any {
    return sub(value, INVISIBLE, "").normalize("NFC");
}

"""Invisible characters stripped, NFC, then the Drive name rules last, as the upload route applies them."""
def importName(value: any) -> any {
    return normalizeDriveName(visible(value)) if isinstance(value, str) else NULL;
}

"""The distinct folders (every prefix of every path) of `paths`."""
def folderPrefixes(paths: any) -> any {
    json = globalThis.JSON.stringify;
    return new(globalThis.Set, [json(p.slice(0, n)) for p in paths for n in range(1, len(p) + 1)]);
}

"""Drive names of an untrusted Takeout entry under `prefix`, rejecting `..`, absolute and deep paths."""
def takeoutDrivePath(entryName: any, prefix: any) -> any {
    name = visible(entryName);
    if name.startsWith("/") or name.startsWith("\\") or rx(r"^[a-zA-Z]:").test(name) {
        return {"error": "its path is absolute"};
    }
    parts = globalThis.String.prototype.split.call(name, rx(r"[\\/]"));
    kept = [p for p in parts if p != "" and p != "."];
    if ".." in kept {
        return {"error": "its path goes up a folder"};
    }
    if any([i >= len(kept) or kept[i] != p for (i, p) in enumerate(prefix)]) {
        return {"error": "it is outside the Drive folder"};
    }
    tail = kept[len(prefix):];
    named = [importName(p) if units(p) <= DRIVE_MAX_NAME_LENGTH else False for p in tail];
    bad = [s for s in named if not s];
    if bad {
        return {"error": "a name is too long" if bad[0] is False else "a name is not usable"};
    }
    directory = parts[len(parts) - 1] == "";
    if len(named) - (0 if directory else 1) > DRIVE_MAX_DEPTH {
        return {"error": "its folders are nested too deeply"};
    }
    return {"segments": named, "directory": directory};
}

def:priv units(s: any) -> int {
    return s.length;
}

def:priv split_name(name: any) -> tuple[any, str] {
    dot = name.lastIndexOf(".");
    return (name.slice(0, dot), name.slice(dot)) if dot > 0 else (name, "");
}

"""`a.docx`, `a (1).docx`, ... `a (99).docx`, each within 255 characters; a dotfile has no extension."""
def collisionCandidates(name: any) -> list[any] {
    (stem, ext) = split_name(name);
    suffixes = [f" ({n}){ext}" for n in range(1, 100)];
    return [name] + [stem.slice(0, DRIVE_MAX_NAME_LENGTH - units(s)) + s for s in suffixes];
}

"""A `LIKE ... ESCAPE '!'` pattern for the candidates after the first (and more: compare exact names)."""
def collisionPattern(name: any) -> str {
    (stem, ext) = split_name(name);
    escape = lambda (text: any) -> str { rx_sub(text, rx("[!%_]", "g"), "!$&") };
    room = DRIVE_MAX_NAME_LENGTH - units(" (99)" + ext);
    # A stem that was cut to fit differs after its first `room` characters, so only that part is known.
    (known, mark) = (stem.slice(0, room), "%") if units(stem) > room else (stem, " (%)");
    return escape(known) + mark + escape(ext);
}

"""Skip if a candidate name holds the finished file (same size), else upload under the first that holds
nothing untrashed or this unfinished file (resumed); `unknown`: look that name up first."""
def planImportFile(known: any, request: any) -> any {
    (size, fp) = (request["size"], request["fingerprint"]);
    for name in collisionCandidates(request["name"]) {
        items = known.get(name);
        if not globalThis.Boolean(items) {
            return {"action": "unknown", "name": name};
        }
        held = [i for i in items if not i["trashed"]];
        files = [i for i in held if i["kind"] == "file" and i["size"] == size];
        if any([not i["pending"] for i in files]) {
            return {"action": "skip"};
        }
        if any([bool(i["pending"]) and i["fingerprint"] == fp for i in files]) or not held {
            return {"action": "upload", "name": name};
        }
    }
    return {"action": "error", "error": "Too many files with this name"};
}

def:priv starts(head: any, hex: str, at: int = 0) -> bool {
    magic = [globalThis.parseInt(hex[i:i + 2], 16) for i in range(0, len(hex), 2)];
    return all([at + i < head.length and head[at + i] == b for (i, b) in enumerate(magic)]);
}

"""Text that opens like markup could be HTML or SVG whatever its extension says."""
def:priv markup(head: any) -> bool {
    bom = 3 if starts(head, "efbbbf") else 0;
    i = head.findIndex(lambda (b: any, at: int) -> bool { at >= bom and b not in [9, 10, 13, 32] });
    return i >= 0 and head[i] == 0x3c;
}

"""The content type for a file name's extension, kept only if `head` (its first bytes, if given) fits."""
def contentTypeForName(name: any, head: any = None) -> any {
    dot = name.lastIndexOf(".");
    kind = TYPES[name.slice(dot + 1).toLowerCase()] if dot > 0 else None;
    if not globalThis.Boolean(kind) or not globalThis.Boolean(head) {
        return kind if globalThis.Boolean(kind) else OPAQUE;
    }
    if kind.startsWith("text/") or kind == "application/json" {
        return OPAQUE if markup(head) or head.includes(0) else kind;
    }
    if owns(MAGIC, kind) {
        webp = kind != "image/webp" or starts(head, "57454250", 8);
        return kind if starts(head, MAGIC[kind]) and webp else OPAQUE;
    }
    zip = rx(r"officedocument|opendocument|\/zip$").test(kind);
    return OPAQUE if zip and not starts(head, "504b") else kind;
}
