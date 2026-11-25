"""
Minimal streaming ZIP writer: STORED entries (the payloads, e.g. attachments, are already
compressed), CRC32 and sizes carried in data descriptors so nothing has to be buffered, and a
central directory at the end. `createZipStream` pulls one entry at a time and yields one chunk per
`pull`, so memory stays bounded regardless of archive size.

An entry is `{ name, modified?, open }`: `name` is the name inside the archive (slashes keep
working as folder separators; backslashes are replaced and `.`/`..` segments dropped), `modified`
defaults to now, and `open` returns the body stream, or null to skip the entry.
"""

# Data descriptor (sizes known only after streaming) plus UTF-8 names.
glob:priv ENTRY_FLAGS: int = 0x0008 | 0x0800,
          VERSION_NEEDED: int = 20,
          LOCAL_HEADER_LENGTH: int = 30,
          DATA_DESCRIPTOR_LENGTH: int = 16,
          CENTRAL_HEADER_LENGTH: int = 46,
          CONTROL_CHARS: any = rx(r"[\u0000-\u001f]", "g"),
          BLANK_SEGMENT: any = rx(r"^[.\s]*$"),
          CRC_TABLE: any = crc_table();

"""
The CRC-32 table as signed 32-bit values: Jac's integer operators are exact and unbounded, so the
arithmetic stays inside int32, where `^` and `&` are the processor's, and `c >>> n` is written
`(c >> n) & mask`.
"""
def:priv crc_table -> any {
    table = new(globalThis.Int32Array, 256);
    for n in range(256) {
        c = n;
        for k in range(8) {
            half = (c >> 1) & 0x7fffffff;
            c = (half ^ -306674912) if c & 1 else half;  # 0xedb88320
        }
        table[n] = c;
    }
    return table;
}

"""Standard CRC-32; pass the previous result to keep accumulating across chunks."""
def crc32(data: any, crc: any = None) -> int {
    c: int = globalThis.Math.imul(either(crc, 0), 1) ^ -1;
    table = CRC_TABLE;
    for index in range(data.byteLength) {
        c = table[(c ^ data[index]) & 0xff] ^ ((c >> 8) & 0xffffff);
    }
    c = c ^ -1;
    return c + 4294967296 if c < 0 else c;
}

def:priv dos_date_time(date: any) -> tuple[int, int] {
    return (
        date.getHours() * 2048
            + date.getMinutes() * 32
            + globalThis.Math.floor(date.getSeconds() / 2),
        (max(date.getFullYear(), 1980) - 1980) * 512 + (date.getMonth() + 1) * 32 + date.getDate(),
    );
}

def:priv zip_entry_name(name: any) -> str {
    cleaned = rx_sub(rx_sub(name, CONTROL_CHARS, ""), rx(r"\\", "g"), "_");
    kept: any = "/".join([seg for seg in cleaned.split("/") if not BLANK_SEGMENT.test(seg)]);
    return kept.trim() or "file";
}

"""Duplicate names make archives ambiguous; later copies get a ` (n)` suffix before the extension."""
def uniqueZipNames(names: any) -> list[str] {
    taken: any = new(globalThis.Set);
    def claim(name: any) -> str {
        candidate: any = zip_entry_name(name);
        dot = candidate.lastIndexOf(".");
        (base, extension) = (candidate.slice(0, dot), candidate.slice(dot))
            if dot > 0
            else (candidate, "");
        copy = 2;
        while taken.has(candidate) {
            candidate = f"{base} ({copy}){extension}";
            copy += 1;
        }
        taken.add(candidate);
        return candidate;
    }
    return [claim(name) for name in names];
}

"""A little-endian header: each field is `(offset, value)`, written as 16 or 32 bits."""
def:priv header(length: int, shorts: list[tuple[int, any]], longs: list[tuple[int, any]]) -> any {
    view = new(globalThis.DataView, new(globalThis.ArrayBuffer, length));
    for (offset, value) in shorts {
        view.setUint16(offset, value, True);
    }
    for (offset, value) in longs {
        view.setUint32(offset, value, True);
    }
    return new(globalThis.Uint8Array, view.buffer);
}

async def:priv generate_zip(entries: any) -> AsyncIterator[any] {
    encoder = new(globalThis.TextEncoder);
    names = uniqueZipNames([item.name for item in entries]);
    central: list[any] = [];
    offset = 0;

    for (index, item) in enumerate(entries) {
        body = await globalThis.Promise.resolve(item.open());
        if not body {
            continue;
        }
        name = encoder.encode(names[index]);
        (dos_time, dos_date) = dos_date_time(either(at(item, "modified"), new(globalThis.Date)));

        # CRC-32 and both sizes stay zero here; the data descriptor after the data carries them.
        yield header(
            LOCAL_HEADER_LENGTH,
            [
                (4, VERSION_NEEDED),
                (6, ENTRY_FLAGS),
                (8, 0),
                (10, dos_time),
                (12, dos_date),
                (26, name.byteLength),
            ],
            [(0, 0x04034b50)],
        );
        yield name;

        crc = 0;
        size = 0;
        reader = body.getReader();
        try {
            while True {
                step = await reader.read();
                if step.done {
                    break;
                }
                if not step.value.byteLength {
                    continue;
                }
                crc = crc32(step.value, crc);
                size += step.value.byteLength;
                yield step.value;
            }
        } finally {
            # Also releases the lock; on a finished body it is a no-op, on early teardown it stops the fetch.
            try {
                await reader.cancel();
            } except Exception {}
        }

        # signature, CRC, compressed size, uncompressed size
        yield header(
            DATA_DESCRIPTOR_LENGTH, [], [(0, 0x08074b50), (4, crc), (8, size), (12, size)]
        );
        central.append((name, crc, size, offset, dos_time, dos_date));
        offset += LOCAL_HEADER_LENGTH + name.byteLength + size + DATA_DESCRIPTOR_LENGTH;
    }

    directory_offset = offset;
    for (name, crc, size, local_offset, dos_time, dos_date) in central {
        # version made by, version needed, flags, method (stored), time, date, name length;
        # signature, CRC, both sizes, offset of the local header
        yield header(
            CENTRAL_HEADER_LENGTH,
            [
                (4, VERSION_NEEDED),
                (6, VERSION_NEEDED),
                (8, ENTRY_FLAGS),
                (10, 0),
                (12, dos_time),
                (14, dos_date),
                (28, name.byteLength),
            ],
            [(0, 0x02014b50), (16, crc), (20, size), (24, size), (42, local_offset)],
        );
        yield name;
        offset += CENTRAL_HEADER_LENGTH + name.byteLength;
    }

    # item counts; signature, central directory size and offset
    yield header(
        22,
        [(8, len(central)), (10, len(central))],
        [(0, 0x06054b50), (12, offset - directory_offset), (16, directory_offset)],
    );
}

"""
Streams `entries` into a ZIP archive. `pull` drives the generator, so only one entry and one chunk
are in flight at a time. An entry whose `open` returns null is left out of the archive.
"""
def createZipStream(entries: any) -> any {
    chunks: any = generate_zip(entries);
    async def pull(controller: any) {
        try {
            controller.enqueue(await chunks.__anext__());
        } except StopAsyncIteration {
            controller.close();
        } except Exception as error {
            controller.error(error);
        }
    }
    async def cancel(reason: any = None) {
        try {
            await chunks.aclose();
        } except Exception {}
    }
    return new(globalThis.ReadableStream, record({"pull": pull, "cancel": cancel}));
}
