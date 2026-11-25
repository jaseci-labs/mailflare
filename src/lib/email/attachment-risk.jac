# Attachment risk without an antivirus engine: it stops one-click downloads of what is dangerous by
# design, not malware in general. EXECUTABLE files run code when opened, MACRO Office formats carry
# macros, CONTAINER files open in a browser or mount like a disk (phishing and smuggling).
glob:priv EXECUTABLE: set[str] = set(
              """exe scr com pif bat cmd msi msp dll cpl jar js jse vbs vbe wsf
              wsh ps1 psm1 lnk hta reg apk appimage scf url chm gadget inf sh command app pkg dmg""".split()
          ),
          MACRO: set[str] = set("docm xlsm pptm dotm xltm potm ppam xlam sldm".split()),
          CONTAINER: set[str] = set("html htm xhtml shtml svg iso img vhd vhdx one".split()),
          ARCHIVE: set[str] = set("zip rar 7z tar gz tgz bz2 xz cab ace".split()),
          DOCUMENT_LOOKING: set[str] = set(
              """pdf doc docx xls xlsx ppt pptx txt rtf jpg jpeg png gif
              csv mp3 mp4""".split()
          ),
          PROGRAM_TYPES: set[str] = set("""application/x-msdownload application/x-msdos-program
              application/x-sh application/vnd.microsoft.portable-executable""".split()),
          BIDI_OR_CONTROL: any = rx(r"[\u0000-\u001f‪-‮⁦-⁩]"),
          TRAILING_SPACE: any = rx(r"\s+$"),
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
    worst: int = 0;
    reasons: list[str] = [];
    for r in risks {
        worst = max(worst, LEVELS.index(r["level"]));
        for x in r["reasons"] {
            if x not in reasons {
                reasons.append(x);
            }
        }
    }
    return risk(LEVELS[worst], reasons);
}

# Risk judged from the name and declared type alone.
def assessAttachmentRisk(attachment: any) -> any {
    filename: any = attachment["filename"];
    exts = [rx_sub(p, TRAILING_SPACE, "") for p in filename.toLowerCase().trim().split(".")[1:]];
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
    if len(exts) >= 2
        and exts[-2] in DOCUMENT_LOOKING
        and (last in EXECUTABLE or last in MACRO or last in CONTAINER)
    {
        found.append(("blocked", "The name has two extensions to look like a harmless document."));
    }
    if globalThis.String(at(attachment, "type", "")).toLowerCase() in PROGRAM_TYPES {
        found.append(("blocked", "The file is declared as a program."));
    }
    return mergeRisks(*[risk(l, [x]) for (l, x) in found]);
}

def:priv read16(view: any, pos: int) -> int {
    v: int = globalThis.DataView.prototype.getUint16.call(view, pos, True);
    return v;
}

def:priv read32(view: any, pos: int) -> int {
    v: int = globalThis.DataView.prototype.getUint32.call(view, pos, True);
    return v;
}

def:priv view_of(data: any) -> any {
    return new(globalThis.DataView, data.buffer, data.byteOffset, data.byteLength);
}

# Where the end-of-central-directory record starts in `tail` (`view` over the same bytes), -1
# without one. Searching back for its first byte (P) skips most positions in one builtin call.
def:priv eocd(tail: any, view: any) -> int {
    i: int = tail.byteLength - 22;
    while i >= 0 {
        i = globalThis.Uint8Array.prototype.lastIndexOf.call(tail, 0x50, i);
        if i < 0 {
            break;
        }
        if read32(view, i) == 0x06054b50 {
            return i;
        }
        i -= 1;
    }
    return -1;
}

# Where a ZIP's central directory sits, from the last 64 KiB of the file.
def locateZipDirectory(tail: any) -> any {
    v = view_of(tail);
    i: int = eocd(tail, v);
    return NULL if i < 0 else record({"size": read32(v, i + 12), "offset": read32(v, i + 16)});
}

# Names inside a ZIP, read from its central directory without extracting anything.
def inspectZipDirectory(tail: any, centralDirectory: any) -> any {
    v = view_of(tail);
    e: int = eocd(tail, v);
    if e < 0 {
        return risk("ok", []);
    }
    count: int = read16(v, e + 10);
    size: int = read32(v, e + 12);
    offset: int = read32(v, e + 16);
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
    dv = view_of(d);
    length: int = d.byteLength;
    decoder = new(globalThis.TextDecoder);
    risks: list[any] = [];
    encrypted = False;
    pos: int = 0;
    seen: int = 0;
    while seen < count and pos + 46 <= length and read32(dv, pos) == 0x02014b50 {
        n: int = read16(dv, pos + 28);  # name length
        if pos + 46 + n > length {
            break;
        }
        if read16(dv, pos + 8) & 1 {
            encrypted = True;
        }
        name: str = decoder.decode(d.subarray(pos + 46, pos + 46 + n));
        slash: int = globalThis.String.prototype.lastIndexOf.call(name, "/");
        inner = assessAttachmentRisk({
            "filename": globalThis.String.prototype.slice.call(name, slash + 1),
        });
        # An "ok" risk has no reasons and changes nothing.
        if inner.level != "ok" {
            why = [f"Inside the archive, {name}: {x}" for x in inner.reasons];
            risks.append(risk(inner.level, why));
        }
        pos += 46 + n + read16(dv, pos + 30) + read16(dv, pos + 32);
        seen += 1;
    }
    if encrypted {
        risks.append(risk("warning", [LOCKED]));
    }
    merged = mergeRisks(*risks);
    return risk(merged["level"], merged["reasons"][:5]);
}
