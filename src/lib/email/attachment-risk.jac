# Attachment risk without an antivirus engine: it stops one-click downloads of what is dangerous by
# design, not malware in general. EXECUTABLE files run code when opened, MACRO Office formats carry
# macros, CONTAINER files open in a browser or mount like a disk (phishing and smuggling).
glob:priv EXECUTABLE: list[str] = """exe scr com pif bat cmd msi msp dll cpl jar js jse vbs vbe wsf
              wsh ps1 psm1 lnk hta reg apk appimage scf url chm gadget inf sh command app pkg dmg""".split(),
          MACRO: list[str] = "docm xlsm pptm dotm xltm potm ppam xlam sldm".split(),
          CONTAINER: list[str] = "html htm xhtml shtml svg iso img vhd vhdx one".split(),
          ARCHIVE: list[str] = "zip rar 7z tar gz tgz bz2 xz cab ace".split(),
          DOCUMENT_LOOKING: list[str] = """pdf doc docx xls xlsx ppt pptx txt rtf jpg jpeg png gif
              csv mp3 mp4""".split(),
          PROGRAM_TYPES: list[str] = """application/x-msdownload application/x-msdos-program
              application/x-sh application/vnd.microsoft.portable-executable""".split(),
          BIDI_OR_CONTROL: any = rx(r"[\u0000-\u001f‪-‮⁦-⁩]"),
          LEVELS: list[str] = ["ok", "warning", "blocked"],
          HIDDEN: str = "The file name contains hidden characters that can disguise its real type.",
          ARCHIVED: str = "Archives can hide other files; open them only if you expected this.",
          BIG: str = "This archive holds an unusually large number of files and was not fully checked.",
          LOCKED: str = "This archive is password protected, so its contents could not be checked.",
          MAX_ZIP_ENTRIES: int = 1000,
          MAX_CENTRAL_DIRECTORY_BYTES: int = 1024 * 1024;
type AttachmentRisk = any;

def:priv risk(level: str, reasons: list[str]) -> any {
    return record({"level": level, "reasons": reasons});
}

def mergeRisks(*risks: any) -> any {
    every = [x for r in risks for x in r["reasons"]];
    worst = max([LEVELS.index(r["level"]) for r in risks] + [0]);
    return risk(LEVELS[worst], [x for (i, x) in enumerate(every) if x not in every[:i]]);
}

# Risk judged from the name and declared type alone.
def assessAttachmentRisk(attachment: any) -> any {
    filename: any = attachment["filename"];
    exts = [rx_sub(p, rx(r"\s+$"), "") for p in filename.toLowerCase().trim().split(".")[1:]];
    last = exts[-1] if exts else "";
    found = [("blocked", HIDDEN)] if BIDI_OR_CONTROL.test(filename) else [];
    if last in EXECUTABLE {
        found.append(("blocked", f".{last} files run code when opened."));
    } elif last in MACRO {
        found.append(("blocked", f".{last} documents can run macros."));
    } elif last in CONTAINER {
        found.append(("warning", f".{last} files can show a fake login page or hide other files."));
    } elif last in ARCHIVE {
        found.append(("warning", ARCHIVED));
    }
    if len(exts) >= 2 and exts[-2] in DOCUMENT_LOOKING and last in EXECUTABLE + MACRO + CONTAINER {
        found.append(("blocked", "The name has two extensions to look like a harmless document."));
    }
    if globalThis.String(at(attachment, "type", "")).toLowerCase() in PROGRAM_TYPES {
        found.append(("blocked", "The file is declared as a program."));
    }
    return mergeRisks(*[risk(l, [x]) for (l, x) in found]);
}

def:priv eocd(tail: any) -> tuple[any, int] {
    view = new(globalThis.DataView, tail.buffer, tail.byteOffset, tail.byteLength);
    for i in range(view.byteLength - 22, -1, -1) {
        if view.getUint32(i, True) == 0x06054b50 {
            return (view, i);
        }
    }
    return (view, -1);
}

# Where a ZIP's central directory sits, from the last 64 KiB of the file.
def locateZipDirectory(tail: any) -> any {
    (v, i) = eocd(tail);
    return NULL
        if i < 0
        else record({"size": v.getUint32(i + 12, True), "offset": v.getUint32(i + 16, True)});
}

# Names inside a ZIP, read from its central directory without extracting anything.
def inspectZipDirectory(tail: any, centralDirectory: any) -> any {
    (v, e) = eocd(tail);
    if e < 0 {
        return risk("ok", []);
    }
    count = v.getUint16(e + 10, True);
    (size, offset) = (v.getUint32(e + 12, True), v.getUint32(e + 16, True));
    if size == 0xffffffff or offset == 0xffffffff or count == 0xffff {
        return risk("warning", ["This archive uses a format that cannot be checked here."]);
    }
    if count > MAX_ZIP_ENTRIES or size > MAX_CENTRAL_DIRECTORY_BYTES {
        return risk("warning", [BIG]);
    }
    d = centralDirectory(offset, size);
    if nil(d) {
        return risk("warning", ["This archive could not be checked."]);
    }
    dv = new(globalThis.DataView, d.buffer, d.byteOffset, d.byteLength);
    (risks, encrypted, pos) = ([], False, 0);
    for _ in range(count) {
        listed = pos + 46 <= d.byteLength and dv.getUint32(pos, True) == 0x02014b50;
        n = dv.getUint16(pos + 28, True) if listed else 0;  # name length
        if not listed or pos + 46 + n > d.byteLength {
            break;
        }
        encrypted = encrypted or bool(dv.getUint16(pos + 8, True) & 1);
        name: str = new(globalThis.TextDecoder).decode(d.subarray(pos + 46, pos + 46 + n));
        inner = assessAttachmentRisk({"filename": name.split("/")[-1]});
        why = [f"Inside the archive, {name}: {x}" for x in inner["reasons"]];
        risks.append(risk(inner["level"], why));  # an "ok" risk has no reasons and changes nothing
        pos += 46 + n + dv.getUint16(pos + 30, True) + dv.getUint16(pos + 32, True);
    }
    risks += [risk("warning", [LOCKED])] if encrypted else [];
    merged = mergeRisks(*risks);
    return risk(merged["level"], merged["reasons"][:5]);
}
