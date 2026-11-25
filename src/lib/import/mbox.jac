glob:priv FROM_LINE: any = rx(r"^From "),
          TRAILING_BREAK: any = rx(r"\r?\n$"),
          # mboxrd: drop one ">" from every quoted ">*From " line, matching the export.
          QUOTED_FROM: any = rx(r"\n>(>*From )", "g");

def splitMboxMessages(content: str) -> list[str] {
    messages: list[any] = [];
    current: list[str] = [];
    def close {
        if current {
            messages.append(
                rx_sub(rx_sub("\n".join(current), TRAILING_BREAK, ""), QUOTED_FROM, "\n$1")
            );
        }
    }
    for line in content.replace("\r\n", "\n").split("\n") {
        if FROM_LINE.test(line) {
            close();
            current = [];
        } else {
            current.append(line);
        }
    }
    close();
    return [message for message in messages if message.trim()];
}

"""Split an mbox given as raw bytes.

Separators and quoting are ASCII, so the bytes are split as a Latin-1 string (one
char per byte, lossless) and turned back into the same bytes, which keeps 8-bit
bodies intact.
"""
def splitMboxBytes(buffer: any) -> list[any] {
    data = new(globalThis.Uint8Array, buffer);
    content = "";
    for index in range(0, data.length, 0x2000) {
        content += globalThis.String.fromCharCode.apply(None, data.subarray(index, index + 0x2000));
    }
    return [latin1_bytes(message) for message in splitMboxMessages(content)];
}

glob:priv EIGHT_BIT: any = rx(r"[\u0080-\u00ff]"),
          ENCODER: any = new(globalThis.TextEncoder);

"""A Latin-1 string's bytes, one per char. Without 8-bit chars they are its UTF-8, which the
encoder writes in one call; otherwise char by char."""
def:priv latin1_bytes(message: any) -> any {
    if not EIGHT_BIT.test(message) {
        encoded = ENCODER.encode(message);
        return encoded.buffer if encoded.byteLength == encoded.buffer.byteLength else encoded.slice().buffer;
    }
    size: int = message.length;
    out = new(globalThis.Uint8Array, size);
    index = 0;
    while index < size {
        globalThis.Reflect.set(out, index, globalThis.String.prototype.charCodeAt.call(message, index));
        index += 1;
    }
    return out.buffer;
}
