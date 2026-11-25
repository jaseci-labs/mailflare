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
glob:priv FLAGS: int = 0x0008 | 0x0800,
          CRC_TABLES: list[list[int]] = crc_tables(),
          CONTROL: any = rx(r"[\u0000-\u001f]", "g"),
          BACKSLASH: any = rx(r"\\", "g"),
          DOTS_ONLY: any = rx(r"^[.\s]*$");

# Header layouts: the length, then each field's width (S 16, L 32 bits, little-endian) and offset.
glob:priv LOCAL: str = "30 L0 S4 S6 S8 S10 S12 S26",
          DESCRIPTOR: str = "16 L0 L4 L8 L12",
          CENTRAL: str = "46 L0 S4 S6 S8 S10 S12 S14 L16 L20 L24 S28 L42",
          END: str = "22 L0 S8 S10 L12 L16";

"""
Eight CRC-32 tables of 256 signed 32-bit values (slice-by-8): table `k` advances a byte followed by
`k` zero bytes. Jac's integers are unbounded, so the arithmetic stays in int32, where `^` and `&` are
the processor's, and `c >>> n` is written `(c >> n) & mask`. Lists of ints, not an Int32Array, so a
lookup is a list index rather than a call through JavaScript.
"""
def:priv crc_tables -> list[list[int]] {
    first: list[int] = [];
    for n in range(256) {
        c: int = n;
        for k in range(8) {
            c = ((c >> 1) & 0x7fffffff) ^ (-306674912 if c & 1 else 0);  # 0xedb88320
        }
        first.append(c);
    }
    tables: list[list[int]] = [first];
    for k in range(7) {
        prev: list[int] = tables[k];
        next_table: list[int] = [];
        for n in range(256) {
            p: int = prev[n];
            next_table.append(((p >> 8) & 0xffffff) ^ first[p & 0xff]);
        }
        tables.append(next_table);
    }
    return tables;
}

"""
Standard CRC-32; pass the previous result to keep accumulating across chunks. Eight bytes per step
(two little-endian int32 reads, eight table lookups), then the tail a byte at a time.
"""
def crc32(data: any, crc: any = None) -> int {
    t0: list[int] = CRC_TABLES[0];
    t1: list[int] = CRC_TABLES[1];
    t2: list[int] = CRC_TABLES[2];
    t3: list[int] = CRC_TABLES[3];
    t4: list[int] = CRC_TABLES[4];
    t5: list[int] = CRC_TABLES[5];
    t6: list[int] = CRC_TABLES[6];
    t7: list[int] = CRC_TABLES[7];
    n: int = data.byteLength;
    view = new(globalThis.DataView, data.buffer, data.byteOffset, n);
    c: int = globalThis.Math.imul(either(crc, 0), 1) ^ -1;
    i: int = 0;
    stop: int = n - 7;
    while i < stop {
        w: int = globalThis.DataView.prototype.getInt32.call(view, i, True);
        a: int = w ^ c;
        b: int = globalThis.DataView.prototype.getInt32.call(view, i + 4, True);
        c = t7[a & 0xff] ^ t6[(a >> 8) & 0xff] ^ t5[(a >> 16) & 0xff] ^ t4[(a >> 24) & 0xff]
            ^ t3[b & 0xff] ^ t2[(b >> 8) & 0xff] ^ t1[(b >> 16) & 0xff] ^ t0[(b >> 24) & 0xff];
        i += 8;
    }
    while i < n {
        byte: int = globalThis.Reflect.get(data, i);
        c = t0[(c ^ byte) & 0xff] ^ ((c >> 8) & 0xffffff);
        i += 1;
    }
    return (c ^ -1) + (4294967296 if (c ^ -1) < 0 else 0);
}

def:priv dos_date_time(d: any) -> any {
    time = d.getHours() * 2048 + d.getMinutes() * 32 + globalThis.Math.floor(d.getSeconds() / 2);
    year = globalThis.Math.max(d.getFullYear(), 1980) - 1980;
    return (time, year * 512 + (d.getMonth() + 1) * 32 + d.getDate());
}

def:priv zip_entry_name(name: any) -> str {
    cleaned: str = rx_sub(rx_sub(name, CONTROL, ""), BACKSLASH, "_");
    kept: list[str] = [];
    for s in globalThis.String.prototype.split.call(cleaned, "/") {
        if not globalThis.RegExp.prototype.test.call(DOTS_ONLY, s) {
            kept.append(s);
        }
    }
    joined: str = globalThis.String.prototype.trim.call("/".join(kept));
    return joined or "file";
}

"""Duplicate names make archives ambiguous; later copies get ` (n)` before the extension."""
def uniqueZipNames(names: any) -> list[str] {
    taken: any = new(globalThis.Set);
    out: list[str] = [];
    for name in names {
        got: str = zip_entry_name(name);
        if globalThis.Set.prototype.has.call(taken, got) {
            dot: int = globalThis.String.prototype.lastIndexOf.call(got, ".");
            base: str = got;
            ext: str = "";
            if dot > 0 {
                base = globalThis.String.prototype.slice.call(got, 0, dot);
                ext = globalThis.String.prototype.slice.call(got, dot);
            }
            copy: int = 2;
            got = base + " (" + str(copy) + ")" + ext;
            while globalThis.Set.prototype.has.call(taken, got) {
                copy += 1;
                got = base + " (" + str(copy) + ")" + ext;
            }
        }
        globalThis.Set.prototype.add.call(taken, got);
        out.append(got);
    }
    return out;
}

def:priv header(layout: str, values: list[any]) -> any {
    fields = layout.split();
    view = new(globalThis.DataView, new(globalThis.ArrayBuffer, int(fields[0])));
    for (field, value) in zip(fields[1:], values) {
        if field[0] == "L" {
            view.setUint32(int(field[1:]), value, True);
        } else {
            view.setUint16(int(field[1:]), value, True);
        }
    }
    return new(globalThis.Uint8Array, view.buffer);
}

async def:priv generate_zip(entries: any) -> AsyncIterator[any] {
    (encoder, names) = (new(globalThis.TextEncoder), uniqueZipNames([e.name for e in entries]));
    central: list[any] = [];
    offset = 0;
    for (index, item) in enumerate(entries) {
        body = await globalThis.Promise.resolve(item.open());
        if not body {
            continue;
        }
        name = encoder.encode(names[index]);
        (t, d) = dos_date_time(either(at(item, "modified"), new(globalThis.Date)));
        # Version 20, method 0 (stored); CRC and sizes stay zero, the data descriptor carries them.
        yield header(LOCAL, [0x04034b50, 20, FLAGS, 0, t, d, name.byteLength]);
        yield name;
        (crc, size, reader) = (0, 0, body.getReader());
        try {
            while not (step := await reader.read()).done {
                if step.value.byteLength {
                    (crc, size) = (crc32(step.value, crc), size + step.value.byteLength);
                    yield step.value;
                }
            }
        } finally {
            # Also releases the lock; a no-op on a finished body, on early teardown stops the fetch.
            try {
                await reader.cancel();
            } except Exception {}
        }
        yield header(DESCRIPTOR, [0x08074b50, crc, size, size]);
        central.append((name, crc, size, offset, t, d));
        offset += 30 + name.byteLength + size + 16;
    }
    start = offset;
    for (name, crc, size, loc, t, d) in central {
        # Made by and needed: version 20; last, the local header's offset.
        fields: list[any] = [0x02014b50, 20, 20, FLAGS, 0, t, d, crc, size, size];
        yield header(CENTRAL, fields + [name.byteLength, loc]);
        yield name;
        offset += 46 + name.byteLength;
    }
    yield header(END, [0x06054b50, len(central), len(central), offset - start, start]);
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
