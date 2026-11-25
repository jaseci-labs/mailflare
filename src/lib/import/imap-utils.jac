glob:priv SPACES: any = rx(r"\s+"),
          SEARCH: any = rx(r"^\* SEARCH(?:\s+(.+))?$", "i"),
          DIGITS: any = rx(r"^\d+$"),
          PERMANENT: any = rx(
              r"login|auth|credential|not allowed|unreadable|no longer exists", "i"
          ),
          CONNECTION: any = rx(
              r"stream was cancelled|connection closed unexpectedly|did not send an OK greeting|connection (?:reset|refused)|timed? ?out",
              "i",
          ),
          MISSING_FOLDER: any = rx(
              r"NONEXISTENT|unknown mailbox|mailbox (?:does not|doesn't) exist|nonexistent namespace|NOSELECT",
              "i",
          ),
          LITERAL: any = rx(r"\{(\d+)\}$"),
          FLAGS: any = rx(r"\bFLAGS \(([^)]*)\)", "i"),
          UTF7_RUN: any = rx(r"&([A-Za-z0-9+,]*)-", "g"),
          NEEDS_UTF7: any = rx(r"&|[^\x20-\x7e]+", "g"),
          LIST: any = rx(r'^\* LIST\s+\([^\)]*\)\s+(?:"[^"]*"|NIL)\s+(.+)$', "i"),
          IPV4: any = rx(r"^\d+\.\d+\.\d+\.\d+$"),
          # FETCH commands sent back to back, and the raw mail one group may hold before the next is requested.
          IMAP_PIPELINE_COUNT = 10,
          IMAP_PIPELINE_BYTES = 4 * 1024 * 1024;

# Connection failures tolerated at the same batch size before it shrinks too: a throttled
# host needs time, a batch that is too heavy needs to be smaller.
glob IMAP_CONNECTION_KEEP_SIZE_FAILURES = 3,
     # Every fetched message is held in memory and then parsed and stored within one
     # Worker request, so a batch stops early once it holds this much raw mail.
     MAX_IMAP_BATCH_BYTES = 20 * 1024 * 1024;

def:priv words(text: any) -> any {
    return globalThis.String.prototype.split.call(text.trim(), SPACES);
}

"""`Math.floor(n) || fallback`: Jac's `or` takes NaN for true."""
def:priv floored(n: any, fallback: any) -> any {
    whole = globalThis.Math.floor(n);
    return fallback if globalThis.Number.isNaN(whole) or whole == 0 else whole;
}

def quoteImapString(value: str) -> str {
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"';
}

def parseSearchUids(line: str) -> list[str] {
    found = SEARCH.exec(line);
    if not found or not found[1] {
        return [];
    }
    return [value for value in words(found[1]) if DIGITS.test(value)];
}

"""Picks one batch of UIDs, newest first.

`offset` is how many of the newest messages earlier batches already covered, so
repeated requests with the returned `nextOffset` (null once the folder is fully
covered) walk back through the whole folder.
"""
def selectImapUidBatch(allUids: any, limit: any, offset: any) -> dict[str, any] {
    M = globalThis.Math;
    total = allUids.length;
    safeOffset = M.min(M.max(floored(offset, 0), 0), total);
    end = total - safeOffset;
    start = M.max(0, end - M.max(floored(limit, 1), 1));
    return {
        "uids": allUids.slice(start, end),
        "total": total,
        "nextOffset": safeOffset + (end - start) if start > 0 else NULL,
    };
}

"""Messages to fetch in one chunk.

`size` is the size the job settled on after earlier trouble; every redelivery of
the same queue message (`attempt` > 1, e.g. the Worker died with a resource-limit
503) halves it again.
"""
def getImapChunkSize(base: any, size: any = None, attempt: any = None) -> any {
    M = globalThis.Math;
    halvings = M.max((1 if nil(attempt) else attempt) - 1, 0);
    current = M.min(M.max(floored(either(size, base), base), 1), base);
    return M.max(1, M.floor(current / 2 ** halvings));
}

"""After a clean chunk, climb back towards `base` gradually rather than all at once."""
def growImapChunkSize(base: any, size: any) -> any {
    M = globalThis.Math;
    return base if size >= base else M.min(base, size + M.max(1, M.floor(size / 2)));
}

"""Errors a smaller batch cannot fix: bad credentials, lost settings."""
def isPermanentImapError(message: str) -> bool {
    return PERMANENT.test(message);
}

"""The server refused or dropped the connection, as opposed to failing on the messages themselves."""
def isImapConnectionError(message: str) -> bool {
    return CONNECTION.test(message);
}

"""Whether a connection failure should retry at the same batch size, given how many failed in a row."""
def keepsImapChunkSize(failures: any) -> bool {
    return failures <= IMAP_CONNECTION_KEEP_SIZE_FAILURES;
}

"""A folder the server says does not exist or cannot be selected, such as Gmail's `[Gmail]` parent."""
def isMissingImapFolderError(message: str) -> bool {
    return MISSING_FOLDER.test(message);
}

"""Splits UIDs (newest first) into groups to pipeline.

The tail that would push the batch past the memory budget is dropped. A UID with
an unknown size travels alone.
"""
def planImapFetchGroups(uids: any, sizes: any) -> list[any] {
    groups: list[any] = [];
    current: list[any] = [];
    (currentBytes, planned) = (0, 0);
    for uid in uids {
        if planned >= MAX_IMAP_BATCH_BYTES {
            break;
        }
        size = sizes.get(uid);
        if size is None {
            if current {
                groups.append(current);
            }
            groups.append([uid]);
            (current, currentBytes, planned) = ([], 0, MAX_IMAP_BATCH_BYTES);
            continue;
        }
        current.append(uid);
        currentBytes += size;
        planned += size;
        if len(current) >= IMAP_PIPELINE_COUNT or currentBytes >= IMAP_PIPELINE_BYTES {
            groups.append(current);
            (current, currentBytes) = ([], 0);
        }
    }
    if current {
        groups.append(current);
    }
    return groups;
}

def getLiteralLength(line: str) -> any {
    found = LITERAL.exec(line);
    return globalThis.Number(found[1]) if found else NULL;
}

"""Uppercased flags from a FETCH response line, or null when the line has none."""
def parseFetchFlags(line: str) -> any {
    found = FLAGS.exec(line);
    if not found {
        return NULL;
    }
    return [flag.toUpperCase() for flag in words(found[1]) if flag];
}

def isTaggedCompletion(line: any, tag: any) -> bool {
    return line.toUpperCase().startsWith(f"{tag.toUpperCase()} ");
}

"""Mailbox name from modified UTF-7 (RFC 3501 5.1.3), e.g. "Entw&APw-rfe" to "Entwürfe"."""
def decodeImapMailboxName(value: str) -> str {
    def decoded(found: any, encoded: any) -> any {
        if not encoded {
            return "&";
        }
        try {
            binary = globalThis.atob(encoded.replaceAll(",", "/"));
        } except Exception {
            return found;
        }
        # The bytes are UTF-16BE; a trailing odd byte is padding.
        return "".join([
            globalThis.String.fromCharCode(
                (binary.charCodeAt(index) << 8) | binary.charCodeAt(index + 1)
            )
            for index in range(0, binary.length - 1, 2)
        ]);
    }
    return rx_sub(value, UTF7_RUN, decoded);
}

"""Mailbox name to modified UTF-7, as SELECT and EXAMINE expect it."""
def encodeImapMailboxName(value: str) -> str {
    def encoded(run: any) -> any {
        if run == "&" {
            return "&-";
        }
        data = new(globalThis.Uint8Array, run.length * 2);
        for index in range(run.length) {
            data[index * 2] = run.charCodeAt(index) >> 8;
            data[index * 2 + 1] = run.charCodeAt(index) & 0xff;
        }
        base64 = globalThis.btoa(globalThis.String.fromCharCode.apply(None, data));
        return "&" + rx_sub(base64, rx(r"=+$"), "").replace("/", ",") + "-";
    }
    return rx_sub(value, NEEDS_UTF7, encoded);
}

def parseListMailboxName(line: str, literal: any = None) -> any {
    found = LIST.exec(line);
    if not found or not found[1] {
        return NULL;
    }
    value: any = found[1].trim();
    # A name sent as a literal ({n}) arrives on the next line.
    if getLiteralLength(value) is not NULL {
        return decodeImapMailboxName(literal) if literal else NULL;
    }
    if value.startsWith('"') and value.endsWith('"') {
        return decodeImapMailboxName(
            value.slice(1, -1).replaceAll('\\"', '"').replaceAll("\\\\", "\\")
        );
    }
    return decodeImapMailboxName(value) if value else NULL;
}

def assertSafeImapHost(host: any) {
    value = host.trim().toLowerCase();
    if not value or value == "localhost" or value.endsWith(".local") {
        raise new(globalThis.Error, "IMAP host is not allowed");
    }
    if IPV4.test(value) {
        (a, b) = [globalThis.Number(part) for part in value.split(".")][:2];
        if a in [10, 127]
            or (a == 172 and 16 <= b <= 31)
            or (a == 192 and b == 168)
            or (a == 169 and b == 254)
        {
            raise new(globalThis.Error, "Private IMAP hosts are not allowed");
        }
    }
}
