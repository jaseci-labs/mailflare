# What the folders route says about a path that nests too deeply; the import card matches it to show its own translated message.
glob NESTED_TOO_DEEPLY = "Folders are nested too deeply";

# Distinct folders one folders request may find or create, every ancestor counted; a 64-deep path fits.
# Bounds the D1 queries of the request.
glob MAX_IMPORT_FOLDERS = 64;

# C0 and C1 controls, bidirectional embeddings, overrides and isolates, and zero-width characters:
# invisible, and able to make one name look like another.
glob:priv INVISIBLE: any = rx(
              r"[\u0000-\u001f\u007f-\u009f\u200b-\u200d\u202a-\u202e\u2066-\u2069\ufeff]", "g"
          ),
          DRIVE_LETTER: any = rx(r"^[a-zA-Z]:"),
          SEPARATOR: any = rx(r"[\\/]"),
          LIKE_SPECIAL: any = rx(r"[!%_]", "g"),
          ZIPPED: any = rx(r"officedocument|opendocument|/zip$"),
          # `name`, then `name (1)` to `name (99)`.
          COLLISION_CANDIDATES = 100,
          OPAQUE = "application/octet-stream",
          # Extension to content type. Anything not listed, HTML, SVG and XML included, is stored as opaque bytes.
          TYPES: dict[str, str] = {
              "pdf": "application/pdf",
              "png": "image/png",
              "jpg": "image/jpeg",
              "jpeg": "image/jpeg",
              "gif": "image/gif",
              "webp": "image/webp",
              "txt": "text/plain",
              "csv": "text/csv",
              "json": "application/json",
              "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
              "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
              "odt": "application/vnd.oasis.opendocument.text",
              "ods": "application/vnd.oasis.opendocument.spreadsheet",
              "odp": "application/vnd.oasis.opendocument.presentation",
              "zip": "application/zip",
              "mp3": "audio/mpeg",
              "mp4": "video/mp4",
          },
          # The bytes, by offset, each binary type must start with. Office and OpenDocument files are zips.
          MAGIC: dict[str, list[any]] = {
              "application/pdf": [(0, [0x25, 0x50, 0x44, 0x46])],
              "image/png": [(0, [0x89, 0x50, 0x4e, 0x47])],
              "image/jpeg": [(0, [0xff, 0xd8, 0xff])],
              "image/gif": [(0, [0x47, 0x49, 0x46, 0x38])],
              "image/webp": [(0, [0x52, 0x49, 0x46, 0x46]), (8, [0x57, 0x45, 0x42, 0x50])],
          },
          ZIP_MAGIC: list[any] = [(0, [0x50, 0x4b])],
          UTF8_BOM: list[any] = [(0, [0xef, 0xbb, 0xbf])];

def:priv visible(value: any) -> any {
    stripped: any = rx_sub(value, INVISIBLE, "");
    return stripped.normalize("NFC");
}

"""A name as Drive items of an import are named: invisible characters stripped, NFC, then the usual Drive name rules
(which trim and replace slashes). The Drive rules apply last because the upload route applies them to whatever it is given."""
def importName(value: any) -> any {
    return normalizeDriveName(visible(value)) if globalThis.String(value) is value else NULL;
}

"""The distinct folders (every prefix of every path) of `paths`."""
def folderPrefixes(paths: any) -> any {
    prefixes = new(globalThis.Set);
    for path in paths {
        for length in range(1, len(path) + 1) {
            prefixes.add(globalThis.JSON.stringify(path[:length]));
        }
    }
    return prefixes;
}

"""The folder and file names of a Takeout zip entry under its Drive folder (`prefix`, e.g. ["Takeout", "Drive"]).
Entry names are untrusted: they only ever become Drive item names, never paths, but they are still strict. Both
slash styles separate segments; invisible characters (see INVISIBLE) are stripped first, so nothing can hide behind
them; `..`, absolute paths, drive letters, names over 255 characters and trees deeper than a Drive allows are
rejected, `.` and empty segments dropped, and every segment is named by importName (the server demands the same)."""
def takeoutDrivePath(entryName: any, prefix: any) -> dict[str, any] {
    name = visible(entryName);
    if name.startsWith("/") or name.startsWith("\\") or DRIVE_LETTER.test(name) {
        return {"error": "its path is absolute"};
    }
    parts: any = globalThis.String.prototype.split.call(name, SEPARATOR);
    directory = parts[len(parts) - 1] == "";
    kept = [part for part in parts if part not in ["", "."]];
    if ".." in kept {
        return {"error": "its path goes up a folder"};
    }
    if len(kept) < len(prefix) or [1 for (i, part) in enumerate(prefix) if kept[i] != part] {
        return {"error": "it is outside the Drive folder"};
    }
    segments: list[str] = [];
    for part in kept[len(prefix):] {
        if part.length > DRIVE_MAX_NAME_LENGTH {
            return {"error": "a name is too long"};
        }
        segment = importName(part);
        if not segment {
            return {"error": "a name is not usable"};
        }
        segments.append(segment);
    }
    if len(segments) - (0 if directory else 1) > DRIVE_MAX_DEPTH {
        return {"error": "its folders are nested too deeply"};
    }
    return {"segments": segments, "directory": directory};
}

"""A name's stem and its last extension; a dotfile has none."""
def:priv split_name(name: any) -> tuple[any, any] {
    dot = name.lastIndexOf(".");
    return (name.slice(0, dot), name.slice(dot)) if dot > 0 else (name, "");
}

"""`a.docx`, `a (1).docx`, ... `a (99).docx`. The last extension stays last, a dotfile has none, and every name fits in 255 characters."""
def collisionCandidates(name: any) -> list[str] {
    (stem, extension) = split_name(name);
    names = [name];
    for n in range(1, COLLISION_CANDIDATES) {
        suffix: any = f" ({n}){extension}";
        names.append(stem.slice(0, DRIVE_MAX_NAME_LENGTH - suffix.length) + suffix);
    }
    return names;
}

def:priv like_escaped(text: any) -> str {
    return rx_sub(text, LIKE_SPECIAL, "!$&");
}

"""A `LIKE ... ESCAPE '!'` pattern that matches every collision candidate after the first (`a (1).docx` to
`a (99).docx`), so one query finds them all. It can match other names too; callers compare exact names."""
def collisionPattern(name: any) -> str {
    (stem, extension) = split_name(name);
    longest: any = f" ({COLLISION_CANDIDATES - 1}){extension}";
    room = DRIVE_MAX_NAME_LENGTH - longest.length;
    # A stem that was cut to fit differs after its first `room` characters, so only that part is known.
    return f"{like_escaped(stem)} (%){like_escaped(extension)}"
        if stem.length <= room
        else f"{like_escaped(stem.slice(0, room))}%{like_escaped(extension)}";
}

"""Decides what to do with one file of a folder, given what is known about the items already there, by exact name
(`known` maps a candidate name to the items called that; a missing key means "not looked up yet"). The first
candidate name that
 1. holds a finished file of the same size: skip, it was imported before;
 2. holds an unfinished upload with the same size and fingerprint: upload under that name, which resumes it;
 3. holds nothing: upload under that name;
otherwise the next one is tried. Trashed items do not hold a name. Returns `unknown` with the name to look up first
when the walk reaches a name `known` lacks."""
def planImportFile(known: any, request: any) -> dict[str, any] {
    for name in collisionCandidates(request["name"]) {
        items = known.get(name);
        if nil(items) {
            return {"action": "unknown", "name": name};
        }
        held = [item for item in items if not item["trashed"]];
        same = [
            item
            for item in held
            if item["kind"] == "file" and item["size"] is request["size"]
        ];
        if [1 for item in same if not item["pending"]] {
            return {"action": "skip"};
        }
        resumable = [
            1
            for item in same
            if item["pending"] and item["fingerprint"] is request["fingerprint"]
        ];
        if resumable or not held {
            return {"action": "upload", "name": name};
        }
    }
    return {"action": "error", "error": "Too many files with this name"};
}

def:priv starts_with(head: any, signature: list[any]) -> bool {
    return not [
        1
        for (offset, expected) in signature
        for (i, byte) in enumerate(expected)
        if offset + i >= head.length or head[offset + i] != byte
    ];
}

"""Text that opens like markup could be HTML or SVG whatever its extension says."""
def:priv looks_like_markup(head: any) -> bool {
    index = 3 if starts_with(head, UTF8_BOM) else 0;
    while index < head.length and head[index] in [0x20, 0x09, 0x0a, 0x0d] {
        index += 1;
    }
    return index < head.length and head[index] == 0x3c;
}

"""The content type to store a file with: from its extension, and, when `head` (its first bytes) is given, only if those bytes fit."""
def contentTypeForName(name: any, head: any = None) -> str {
    dot = name.lastIndexOf(".");
    kind = TYPES.get(name.slice(dot + 1).toLowerCase()) if dot > 0 else None;
    if not kind {
        return OPAQUE;
    }
    if nil(head) {
        return kind;
    }
    if kind.startswith("text/") or kind == "application/json" {
        return OPAQUE if looks_like_markup(head) or head.includes(0) else kind;
    }
    signature = MAGIC.get(kind) or (ZIP_MAGIC if ZIPPED.test(kind) else None);
    return OPAQUE if signature and not starts_with(head, signature) else kind;
}
