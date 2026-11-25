"""Attachment risk without an antivirus engine.

File types that run code or carry macros, names that disguise their type, and the contents of ZIP
archives (bounded). It does not detect malware in ordinary-looking files; it stops a one-click
download of things that are dangerous by design. A risk is `{level, reasons}` with level `ok`,
`warning` or `blocked`.
"""

# Run code when opened.
glob:priv EXECUTABLE: list[str] = [
    "exe",
    "scr",
    "com",
    "pif",
    "bat",
    "cmd",
    "msi",
    "msp",
    "dll",
    "cpl",
    "jar",
    "js",
    "jse",
    "vbs",
    "vbe",
    "wsf",
    "wsh",
    "ps1",
    "psm1",
    "lnk",
    "hta",
    "reg",
    "apk",
    "appimage",
    "scf",
    "url",
    "chm",
    "gadget",
    "inf",
    "sh",
    "command",
    "app",
    "pkg",
    "dmg",
];

# Office formats that carry macros.
glob:priv MACRO: list[str] = [
    "docm",
    "xlsm",
    "pptm",
    "dotm",
    "xltm",
    "potm",
    "ppam",
    "xlam",
    "sldm",
];

# Open in a browser or mount like a disk: common phishing and smuggling containers.
glob:priv CONTAINER: list[str] = [
    "html",
    "htm",
    "xhtml",
    "shtml",
    "svg",
    "iso",
    "img",
    "vhd",
    "vhdx",
    "one",
];

glob:priv ARCHIVE: list[str] = ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "cab", "ace"],
          DOCUMENT_LOOKING: list[str] = [
              "pdf",
              "doc",
              "docx",
              "xls",
              "xlsx",
              "ppt",
              "pptx",
              "txt",
              "rtf",
              "jpg",
              "jpeg",
              "png",
              "gif",
              "csv",
              "mp3",
              "mp4",
          ],
          PROGRAM_TYPES: list[str] = [
              "application/x-msdownload",
              "application/x-msdos-program",
              "application/x-sh",
              "application/vnd.microsoft.portable-executable",
          ],
          BIDI_OR_CONTROL: any = rx(r"[\u0000-\u001f‪-‮⁦-⁩]"),
          TRAILING_SPACE: any = rx(r"\s+$"),
          RANK: dict[str, int] = {"ok": 0, "warning": 1, "blocked": 2};

glob:priv MAX_ZIP_ENTRIES: int = 1000,
          MAX_CENTRAL_DIRECTORY_BYTES: int = 1024 * 1024,
          MAX_ZIP_DEPTH_NAMES: int = 50,
          END_OF_DIRECTORY: int = 0x06054b50,
          DIRECTORY_ENTRY: int = 0x02014b50;

def:priv extensions(filename: any) -> list[str] {
    parts: list[str] = filename.toLowerCase().trim().split(".");
    return [rx_sub(part, TRAILING_SPACE, "") for part in parts[1:]];
}

def:priv warning(reason: str) -> dict[str, any] {
    return {"level": "warning", "reasons": [reason]};
}

def mergeRisks(*risks: any) -> dict[str, any] {
    level = "ok";
    reasons: list[str] = [];
    for risk in risks {
        if RANK[risk["level"]] > RANK[level] {
            level = risk["level"];
        }
        reasons += [reason for reason in risk["reasons"] if reason not in reasons];
    }
    return {"level": level, "reasons": reasons};
}

"""Risk judged from the name and declared type alone."""
def assessAttachmentRisk(attachment: any) -> dict[str, any] {
    filename = attachment["filename"];
    found: list[tuple[str, str]] = [];
    exts = extensions(filename);
    last = exts[-1] if exts else "";
    if BIDI_OR_CONTROL.test(filename) {
        found.append((
            "blocked",
            "The file name contains hidden characters that can disguise its real type.",
        ));
    }
    if last in EXECUTABLE {
        found.append(("blocked", f".{last} files run code when opened."));
    } elif last in MACRO {
        found.append(("blocked", f".{last} documents can run macros."));
    } elif last in CONTAINER {
        found.append(("warning", f".{last} files can show a fake login page or hide other files."));
    } elif last in ARCHIVE {
        found.append((
            "warning",
            "Archives can hide other files; open them only if you expected this.",
        ));
    }
    if len(exts) >= 2 and exts[-2] in DOCUMENT_LOOKING and last in EXECUTABLE + MACRO + CONTAINER {
        found.append(("blocked", "The name has two extensions to look like a harmless document."));
    }
    declared: any = at(attachment, "type", "");
    if declared.toLowerCase() in PROGRAM_TYPES {
        found.append(("blocked", "The file is declared as a program."));
    }
    level = "ok";
    for (next_level, reason) in found {
        if RANK[next_level] > RANK[level] {
            level = next_level;
        }
    }
    return {"level": level, "reasons": [reason for (next_level, reason) in found]};
}

def:priv data_view(chunk: any) -> any {
    return new(globalThis.DataView, chunk.buffer, chunk.byteOffset, chunk.byteLength);
}

"""Index of the end-of-central-directory record, searched from the end; -1 when there is none."""
def:priv end_of_directory(view: any) -> int {
    for index in range(view.byteLength - 22, -1, -1) {
        if view.getUint32(index, True) == END_OF_DIRECTORY {
            return index;
        }
    }
    return -1;
}

"""Where a ZIP's central directory sits, from the last 64 KiB of the file."""
def locateZipDirectory(tail: any) -> any {
    view = data_view(tail);
    index = end_of_directory(view);
    if index < 0 {
        return NULL;
    }
    return {"size": view.getUint32(index + 12, True), "offset": view.getUint32(index + 16, True)};
}

"""Names inside a ZIP, read from its central directory without extracting anything."""
def inspectZipDirectory(tail: any, centralDirectory: any) -> dict[str, any] {
    view = data_view(tail);
    eocd = end_of_directory(view);
    if eocd < 0 {
        return {"level": "ok", "reasons": []};
    }
    count = view.getUint16(eocd + 10, True);
    size = view.getUint32(eocd + 12, True);
    offset = view.getUint32(eocd + 16, True);
    if size == 0xffffffff or offset == 0xffffffff or count == 0xffff {
        return warning("This archive uses a format that cannot be checked here.");
    }
    if count > MAX_ZIP_ENTRIES or size > MAX_CENTRAL_DIRECTORY_BYTES {
        return warning(
            "This archive holds an unusually large number of files and was not fully checked."
        );
    }
    directory = centralDirectory(offset, size);
    if nil(directory) {
        return warning("This archive could not be checked.");
    }
    dv = data_view(directory);
    risks: list[any] = [];
    encrypted = False;
    position = 0;
    for seen in range(globalThis.Math.min(count, MAX_ZIP_DEPTH_NAMES * 20)) {
        if position + 46 > directory.byteLength or dv.getUint32(position, True) != DIRECTORY_ENTRY {
            break;
        }
        flags = dv.getUint16(position + 8, True);
        name_length = dv.getUint16(position + 28, True);
        extra_length = dv.getUint16(position + 30, True);
        comment_length = dv.getUint16(position + 32, True);
        if position + 46 + name_length > directory.byteLength {
            break;
        }
        if flags & 1 {
            encrypted = True;
        }
        name: str = new(globalThis.TextDecoder).decode(
            directory.subarray(position + 46, position + 46 + name_length)
        );
        inner = assessAttachmentRisk({"filename": name.split("/")[-1]});
        if inner["level"] != "ok" {
            risks.append({
                "level": inner["level"],
                "reasons": [f"Inside the archive, {name}: {reason}" for reason in inner["reasons"]],
            });
        }
        position += 46 + name_length + extra_length + comment_length;
    }
    if encrypted {
        risks.append(
            warning("This archive is password protected, so its contents could not be checked.")
        );
    }
    merged = mergeRisks(*risks);
    return {"level": merged["level"], "reasons": merged["reasons"][:5]};
}

# Types that TypeScript modules still import by name.
type AttachmentRisk = dict[str, any];
