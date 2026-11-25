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
    def packed(message: any) -> any {
        out = new(globalThis.Uint8Array, message.length);
        for index in range(message.length) {
            out[index] = message.charCodeAt(index);
        }
        return out.buffer;
    }
    return [packed(message) for message in splitMboxMessages(content)];
}
