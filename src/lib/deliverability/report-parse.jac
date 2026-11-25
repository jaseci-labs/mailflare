"""
Pure, bounded parsing of DMARC aggregate (rua) and TLS-RPT (RFC 8460) reports. Report mail is attacker-controlled, so every
stage has a cap: compressed size, decompressed size and expansion ratio, zip entry count, record count,
distinct rows and field lengths. Nothing here fetches a URL or expands an XML entity.
"""

glob REPORT_LIMITS: any = globalThis.Object.freeze(
         record({
             "rawMessageBytes": 5 * 1024 * 1024,
             "compressedBytes": 3 * 1024 * 1024,
             "decompressedBytes": 8 * 1024 * 1024,
             # Decompressed bytes may not exceed this multiple of the compressed bytes ...
             "maxExpansionRatio": 1000,
             # Compressed input reaches the inflater in slices of this size, so one write can only expand so far before the byte counter looks.
             "inputSliceBytes": 16 * 1024,
             # ... except that anything up to this size is always allowed, so tiny valid reports never trip the ratio.
             "ratioFloorBytes": 64 * 1024,
             "records": 20000,
             # Distinct (source, result) rows written per report, highest volume first.
             "rows": 500,
             # A per-row count above this is not a real mail volume for one source and result in one report.
             "maxCount": 10000000,
             "ip": 45,
             "domain": 253,
             "org": 128,
             "email": 254,
             "reportId": 256,
             # A report may start at most this far in the future, and at most this long ago (the retention window).
             "maxFutureSeconds": 24 * 60 * 60,
             "maxAgeSeconds": 180 * 24 * 60 * 60,
             # Reports cover a day; a longer range is refused, so one report cannot be spread over a long period.
             "maxRangeSeconds": 7 * 24 * 60 * 60,
         }),
     ),
     TLS_LIMITS: any = globalThis.Object.freeze(
         record({"policies": 1000, "failureDetails": 100, "depth": 8, "resultType": 64})
     );

# Types the TypeScript callers name.
type DmarcRow = dict[str, any];
type DmarcReport = dict[str, any];
type TlsRow = dict[str, any];
type TlsReport = dict[str, any];

glob:priv NAME_PREFIX: str = r"(?:[A-Za-z_][\w.-]*:)?",
          patterns: dict[str, tuple[any, any]] = {},
          ENTITIES: dict[str, str] = {"lt": "<", "gt": ">", "quot": '"', "apos": "'", "amp": "&"},
          ENTITY: any = rx(r"&(?:(lt|gt|quot|apos|amp)|#(\d{1,7})|#x([0-9a-fA-F]{1,6}));", "g"),
          CDATA: any = rx(r"^\s*<!\[CDATA\[([\s\S]*)\]\]>\s*$"),
          CONTROL: any = rx("[\\u0000-\\u001f\\u007f]", "g"),
          BOM: any = rx("^\\uFEFF"),
          ROOT_DOT: any = rx(r"\.$"),
          DIGITS: any = rx(r"^\d{1,12}$"),
          DECLARATION: any = rx("<!DOCTYPE|<!ENTITY", "i"),
          XML_NAME: any = rx(r"\.xml$", "i"),
          RFC3339: any = rx(
              r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$", "i"
          ),
          MX_HOST: any = rx(r"^[a-z0-9*._-]+$"),
          RESULT_TYPE: any = rx(r"^[a-z0-9-]{1,64}$"),
          POLICY_TYPES: list[str] = ["sts", "tlsa", "no-policy-found"],
          LAST_SECOND: int = 4102444800;

"""`status` is `rejected` for a report that must not be read, `failed` for one that could not be."""
obj ReportError(globalThis.Error) {
    has status: str = "";

    def init(status: str, message: str) {
        super.init(message);
        self.status = status;
    }
}

# ---- extraction -----------------------------------------------------------------

"""The whole stream as bytes; the byte counter is what enforces `limit`."""
async def:priv read_capped(stream: any, limit: int) -> any {
    reader = stream.getReader();
    chunks: list[any] = [];
    total = 0;
    try {
        while True {
            step = await reader.read();
            if step.done {
                break;
            }
            total += step.value.length;
            if total > limit {
                raise ReportError(
                    "rejected", "Decompressed size exceeds the limit or expansion ratio"
                );
            }
            chunks.append(step.value);
        }
    } finally {
        await reader.cancel().catch(lambda (e: any) -> any { None });
    }
    out = new(globalThis.Uint8Array, total);
    offset = 0;
    for chunk in chunks {
        out.set(chunk, offset);
        offset += chunk.length;
    }
    return out;
}

def:priv starts_with(data: any, prefix: list[int]) -> bool {
    return data.length >= len(prefix) and all([data[i] == byte for (i, byte) in enumerate(prefix)]);
}

def:priv decoded(data: any) -> any {
    return rx_sub(new(globalThis.TextDecoder).decode(data), BOM, "");
}

async def:priv unpacked(data: any, allowed: int) -> any {
    if starts_with(data, [0x1f, 0x8b]) {
        input = new(globalThis.Blob, [data]).stream().pipeThrough(
            sliceChunks(REPORT_LIMITS.inputSliceBytes)
        );
        return await read_capped(
            input.pipeThrough(new(globalThis.DecompressionStream, "gzip")), allowed
        );
    }
    if starts_with(data, [0x50, 0x4b, 0x03, 0x04]) {
        blob = new(globalThis.Blob, [data]);
        found = await listZipEntries(blob);
        if len(found) != 1 {
            raise ReportError("rejected", "A report zip must contain exactly one file");
        }
        item = found[0];
        if item["encrypted"] {
            raise ReportError("rejected", "The report zip is encrypted");
        }
        if item["method"] not in [0, 8] {
            raise ReportError("rejected", "The report zip uses an unsupported compression method");
        }
        if not XML_NAME.test(item["name"]) {
            raise ReportError("rejected", "The report zip entry is not an .xml file");
        }
        # The declared size is checked first but never trusted: the byte counter is what enforces the cap.
        if item["size"] > allowed {
            raise ReportError("rejected", "Declared size exceeds the limit or expansion ratio");
        }
        return await read_capped(
            await openZipEntry(blob, item, {"maxInputBytes": REPORT_LIMITS.inputSliceBytes}),
            allowed,
        );
    }
    head = decoded(data.subarray(0, 64)).trimStart();
    if not head.startsWith("<") and not head.startsWith("{") {
        raise ReportError("rejected", "The attachment is not a report");
    }
    return data;
}

"""Turns a report attachment (zip, gzip, plain XML or plain JSON, detected by content) into text, within the limits. A zip may only hold an .xml file."""
async def extractReportXml(data: any) -> str {
    if data.length > REPORT_LIMITS.compressedBytes {
        raise ReportError("rejected", "Attachment exceeds the size limit");
    }
    allowed = min(
        REPORT_LIMITS.decompressedBytes,
        max(REPORT_LIMITS.ratioFloorBytes, data.length * REPORT_LIMITS.maxExpansionRatio),
    );
    try {
        return decoded(await unpacked(data, allowed));
    } except Exception as e {
        # What JavaScript threw; `e` itself is Jac's wrapper of it.
        wrapper: any = e;
        thrown = getattr(wrapper, "js", wrapper);
        if isinstance(thrown, ReportError) {
            raise thrown;
        }
        reason = thrown.message if isinstance(thrown, globalThis.Error) else "unknown error";
        message: any = f"Could not read the attachment: {reason}";
        raise ReportError("failed", message.slice(0, 300));
    }
}

# ---- XML (linear-time, no entity expansion) --------------------------------------

"""Matchers for `<name` and `</name >`, with an optional namespace prefix so `<d:record>` is found as `record`."""
def:priv tag_patterns(name: str) -> tuple[any, any] {
    if name not in patterns {
        patterns[name] = (
            rx(f"<{NAME_PREFIX}{name}(?=[\\s/>])", "g"),
            rx(f"</{NAME_PREFIX}{name}\\s*>", "g"),
        );
    }
    return patterns[name];
}

"""Index of the `>` that ends a tag whose name ended at `start`, skipping a `>` inside a quoted attribute value; -1 when there is none."""
def:priv tag_end(source: any, start: int) -> int {
    quote = 0;
    index = start;
    size: int = source.length;
    while index < size {
        code: int = source.charCodeAt(index);
        if quote {
            if code == quote {
                quote = 0;
            }
        } elif code == 34 or code == 39 {
            quote = code;
        } elif code == 62 {
            return index;
        }
        index += 1;
    }
    return -1;
}

"""Removes `<!-- -->` comments outside CDATA in one linear pass, so a commented-out id or record is never read."""
def:priv strip_comments(xml: any) -> str {
    if xml.indexOf("<!--") < 0 {
        return xml;
    }
    parts: list[str] = [];
    pos = 0;
    cdata: int = xml.indexOf("<![CDATA[");
    while True {
        comment: int = xml.indexOf("<!--", pos);
        if comment < 0 {
            break;
        }
        if 0 <= cdata < pos {
            cdata = xml.indexOf("<![CDATA[", pos);
        }
        if 0 <= cdata < comment {
            close: int = xml.indexOf("]]>", cdata + 9);
            stop: int = xml.length if close < 0 else close + 3;
            parts.append(xml.slice(pos, stop));
            pos = stop;
            continue;
        }
        end: int = xml.indexOf("-->", comment + 4);
        if end < 0 {
            raise ReportError("rejected", "Unterminated comment");
        }
        parts.append(xml.slice(pos, comment));
        pos = end + 3;
    }
    parts.append(xml.slice(pos));
    return "".join(parts);
}

"""The inner text of the first `<name>` at or after `start`, and where to look for the next one. Regex searches and indexOf scans only move forward, so hostile nesting stays linear."""
def:priv read_tag(source: any, name: str, start: int = 0) -> any {
    (opening, closing) = tag_patterns(name);
    opening.lastIndex = start;
    found = opening.exec(source);
    if not found {
        return None;
    }
    gt = tag_end(source, found.index + found[0].length);
    if gt < 0 {
        return None;
    }
    if source.charCodeAt(gt - 1) == 47 {
        return ("", gt + 1);
    }
    closing.lastIndex = gt + 1;
    end = closing.exec(source);
    if not end {
        return None;
    }
    return (source.slice(gt + 1, end.index), end.index + end[0].length);
}

"""The inner text of the first `<name>`, empty without one."""
def:priv inner(source: any, name: str) -> str {
    found = read_tag(source, name);
    return found[0] if found else "";
}

def:priv count_tags(source: str, name: str, limit: int) -> int {
    opening = tag_patterns(name)[0];
    opening.lastIndex = 0;
    count = 0;
    while count <= limit and opening.exec(source) {
        count += 1;
    }
    return count;
}

"""One pass, so `&amp;lt;` becomes `&lt;` and never `<`. An out-of-range numeric reference is left as written."""
def:priv unescape_xml(value: str) -> str {
    def entity(whole: str, name: any, decimal: any, hex: any) -> str {
        if name {
            return ENTITIES[name];
        }
        code = globalThis.Number(decimal)
            if decimal is not None
            else globalThis.Number.parseInt(hex, 16);
        valid = 1 <= code <= 0x10ffff and (code < 0xd800 or code > 0xdfff);
        return globalThis.String.fromCodePoint(code) if valid else whole;
    }
    return rx_sub(value, ENTITY, entity);
}

"""A value without control characters, trimmed, at most `limit` characters."""
def:priv clean(value: str, limit: int) -> any {
    stripped: any = rx_sub(value, CONTROL, "");
    return stripped.trim().slice(0, limit);
}

def:priv text(source: any, name: str, limit: int) -> any {
    raw = inner(source, name);
    cdata = CDATA.exec(raw);
    return clean(cdata[1] if cdata else unescape_xml(raw), limit);
}

def:priv strict_int(value: str, limit: int) -> any {
    return globalThis.Number(value)
        if DIGITS.test(value) and globalThis.Number(value) <= limit
        else NULL;
}

def:priv host_of(value: any) -> str {
    return rx_sub(value.toLowerCase(), ROOT_DOT, "");
}

"""`policy` must be the configured domain or a subdomain of it. A parent domain is not accepted."""
def:priv covers(hostname: str, policy: str) -> bool {
    return policy == hostname or policy.endswith(f".{hostname}");
}

"""A report may start from 180 days ago to a day ahead and cover at most 7 days, so one report cannot be spread over a long period. Seconds since the epoch."""
def:priv check_window(begin: int, end: int, now: any) {
    now_seconds = globalThis.Math.floor(now.getTime() / 1000);
    if begin > now_seconds + REPORT_LIMITS.maxFutureSeconds
        or begin < now_seconds - REPORT_LIMITS.maxAgeSeconds
    {
        raise ReportError("rejected", "Report date is outside the accepted window");
    }
    if end - begin > REPORT_LIMITS.maxRangeSeconds {
        raise ReportError("rejected", "The report date range is longer than 7 days");
    }
}

"""What both report kinds say of their window and of the rows kept, highest volume first."""
def:priv window_and_rows(begin: int, end: int, ordered: list[any]) -> dict[str, any] {
    return {
        "dateBegin": new(globalThis.Date, begin * 1000),
        "dateEnd": new(globalThis.Date, max(end, begin) * 1000),
        "day": new(globalThis.Date, begin * 1000).toISOString().slice(0, 10),
        "rows": ordered[:REPORT_LIMITS.rows],
        "truncated": len(ordered) > REPORT_LIMITS.rows,
    };
}

def parseDmarcAggregateXml(source: str, options: any) -> dict[str, any] {
    if DECLARATION.test(source) {
        raise ReportError("rejected", "DOCTYPE and ENTITY declarations are not accepted");
    }
    xml = strip_comments(source);
    if count_tags(xml, "feedback", 0) == 0 {
        raise ReportError("rejected", "Not a DMARC aggregate report");
    }
    if count_tags(xml, "record", REPORT_LIMITS.records) > REPORT_LIMITS.records {
        raise ReportError("rejected", f"More than {REPORT_LIMITS.records} records");
    }
    metadata = inner(xml, "report_metadata");
    reporter_org = text(metadata, "org_name", REPORT_LIMITS.org);
    report_id = text(metadata, "report_id", REPORT_LIMITS.reportId);
    if not reporter_org or not report_id {
        raise ReportError("failed", "Missing org_name or report_id");
    }
    date_range = inner(metadata, "date_range");
    begin = strict_int(text(date_range, "begin", 20), LAST_SECOND);
    if begin is NULL {
        raise ReportError("failed", "Missing or invalid date_range");
    }
    end = either(strict_int(text(date_range, "end", 20), LAST_SECOND), begin);
    check_window(begin, end, options["now"]);

    policy = inner(xml, "policy_published");
    policy_domain = host_of(text(policy, "domain", REPORT_LIMITS.domain));
    if not policy_domain or not covers(host_of(options["hostname"]), policy_domain) {
        raise ReportError("rejected", "Domain mismatch");
    }
    p = text(policy, "p", 16).toLowerCase();

    rows: dict[str, any] = {};
    (record_count, message_count, cursor) = (0, 0, 0);
    while True {
        found = read_tag(xml, "record", cursor);
        if not found {
            break;
        }
        (content, cursor) = found;
        record_count += 1;
        row = inner(content, "row");
        source_ip = text(row, "source_ip", REPORT_LIMITS.ip).toLowerCase();
        count = strict_int(text(row, "count", 12), REPORT_LIMITS.maxCount);
        if not count or reverseName(source_ip) is NULL {
            continue;
        }
        evaluated = inner(row, "policy_evaluated");
        disposition = text(evaluated, "disposition", 16).toLowerCase();
        item = {
            "sourceIp": source_ip,
            "headerFrom": host_of(
                text(inner(content, "identifiers"), "header_from", REPORT_LIMITS.domain)
            )
                or policy_domain,
            "disposition": disposition if disposition in ["quarantine", "reject"] else "none",
            "dkimAligned": text(evaluated, "dkim", 16).toLowerCase() == "pass",
            "spfAligned": text(evaluated, "spf", 16).toLowerCase() == "pass",
            "count": count,
        };
        message_count += count;
        key = f"{source_ip}|{item['headerFrom']}|{item['disposition']}|{item['dkimAligned']}|{item['spfAligned']}";
        if key in rows {
            rows[key]["count"] += count;
        } else {
            rows[key] = item;
        }
    }
    if record_count == 0 {
        raise ReportError("failed", "The report has no records");
    }
    ordered = sorted(rows.values(), key=lambda (row: any) -> any { -row["count"] });
    return {
        "reporterOrg": reporter_org,
        "reporterEmail": text(metadata, "email", REPORT_LIMITS.email) or NULL,
        "reportId": report_id,
        "policyDomain": policy_domain,
        "policyP": p if p in ["none", "quarantine", "reject"] else NULL,
        "policyPct": strict_int(text(policy, "pct", 5), 100),
        "recordCount": record_count,
        "messageCount": message_count,
        **window_and_rows(begin, end, ordered),
    };
}

# ---- TLS-RPT (JSON) ---------------------------------------------------------------

"""Deepest nesting of `[`/`{` outside strings, one linear pass, so a hostile document is refused before `JSON.parse` sees it."""
def:priv json_depth_within(source: any, limit: int) -> bool {
    depth = 0;
    in_string = False;
    index = 0;
    size: int = source.length;
    while index < size {
        code: int = source.charCodeAt(index);
        if in_string {
            if code == 92 {
                index += 1;
            } elif code == 34 {
                in_string = False;
            }
        } elif code == 34 {
            in_string = True;
        } elif code == 91 or code == 123 {
            depth += 1;
            if depth > limit {
                return False;
            }
        } elif code == 93 or code == 125 {
            depth -= 1;
        }
        index += 1;
    }
    return True;
}

"""True of a JavaScript object that is not an array."""
def:priv is_object(value: any) -> bool {
    return globalThis.Object(value) is value
        and not callable(value)
        and not globalThis.Array.isArray(value);
}

def:priv json_text(value: any, limit: int) -> any {
    return clean(value, limit) if isinstance(value, str) else "";
}

def:priv session_count(value: any) -> int {
    if value is None {
        return 0;
    }
    if not globalThis.Number.isInteger(value) or value < 0 or value > REPORT_LIMITS.maxCount {
        raise ReportError("rejected", "A session count is not a whole number from 0 to 10,000,000");
    }
    return value;
}

def:priv report_seconds(value: any) -> int {
    stamp = json_text(value, 40);
    milliseconds = globalThis.Date.parse(stamp) if RFC3339.test(stamp) else globalThis.Number.NaN;
    if not globalThis.Number.isFinite(milliseconds) {
        raise ReportError("failed", "Missing or invalid date-range");
    }
    return globalThis.Math.floor(milliseconds / 1000);
}

"""The first well-formed MX host pattern of a policy (`*.mail.example` is valid), or null."""
def:priv mx_host_of(value: any) -> any {
    for candidate in (value.slice(0, 20) if globalThis.Array.isArray(value) else [value]) {
        host = host_of(json_text(candidate, REPORT_LIMITS.domain));
        if MX_HOST.test(host) {
            return host;
        }
    }
    return NULL;
}

"""
Parses an RFC 8460 TLS-RPT report. The text is size-capped by `extractReportXml` already; here the nesting depth,
the number of policies and failure details, every count and the dates are bounded before anything is kept. Policies
about other domains and unknown policy types are ignored; a report with none of this domain's is rejected.
"""
def parseTlsRptJson(source: str, options: any) -> dict[str, any] {
    if not json_depth_within(source, TLS_LIMITS.depth) {
        raise ReportError("rejected", "The report is nested too deeply");
    }
    try {
        top = globalThis.JSON.parse(source);
    } except Exception {
        raise ReportError("rejected", "Not a TLS-RPT report");
    }
    if not is_object(top) or not globalThis.Array.isArray(top["policies"]) {
        raise ReportError("rejected", "Not a TLS-RPT report");
    }
    if top["policies"].length > TLS_LIMITS.policies {
        raise ReportError("rejected", f"More than {TLS_LIMITS.policies} policies");
    }
    reporter_org = json_text(top["organization-name"], REPORT_LIMITS.org);
    report_id = json_text(top["report-id"], REPORT_LIMITS.reportId);
    if not reporter_org or not report_id {
        raise ReportError("failed", "Missing organization-name or report-id");
    }
    date_range = top["date-range"] if is_object(top["date-range"]) else {};
    begin = report_seconds(at(date_range, "start-datetime"));
    end = report_seconds(at(date_range, "end-datetime"));
    check_window(begin, end, options["now"]);

    hostname = host_of(options["hostname"]);
    rows: dict[str, any] = {};
    (owned, record_count, message_count) = (0, 0, 0);
    for item in top["policies"] {
        policy = item["policy"] if is_object(item) and is_object(item["policy"]) else None;
        if not policy
            or not covers(
                hostname, host_of(json_text(policy["policy-domain"], REPORT_LIMITS.domain))
            )
        {
            continue;
        }
        owned += 1;
        policy_type = policy["policy-type"];
        if not isinstance(policy_type, str) or policy_type not in POLICY_TYPES {
            continue;
        }
        summary = item["summary"] if is_object(item["summary"]) else None;
        details = item["failure-details"];
        if details is not None
            and (
                not globalThis.Array.isArray(details) or details.length > TLS_LIMITS.failureDetails
            )
        {
            raise ReportError(
                "rejected", f"More than {TLS_LIMITS.failureDetails} failure details in a policy"
            );
        }
        mx_host = mx_host_of(policy["mx-host"]);
        produced = False;

        # A failure names the host that failed when the reporter says which (a well-formed one); successes and the rest only know the policy's pattern.
        def add(result_type: str, success: int, failure: int, host: any) {
            if success == 0 and failure == 0 {
                return;
            }
            produced = True;
            message_count += success + failure;
            key = f"{policy_type}|{either(host, '')}|{result_type}";
            if key in rows {
                rows[key]["success"] += success;
                rows[key]["failure"] += failure;
            } else {
                rows[key] = {
                    "policyType": policy_type,
                    "mxHost": host,
                    "resultType": result_type,
                    "success": success,
                    "failure": failure,
                };
            }
        }
        add(
            "",
            session_count(summary["total-successful-session-count"] if summary else None),
            0,
            mx_host,
        );
        detailed = 0;
        for detail in either(details, []) {
            if not is_object(detail) {
                continue;
            }
            count = session_count(detail["failed-session-count"]);
            kind = json_text(detail["result-type"], TLS_LIMITS.resultType).toLowerCase();
            detailed += count;
            add(
                kind if RESULT_TYPE.test(kind) else "other",
                0,
                count,
                either(mx_host_of(detail["receiving-mx-hostname"]), mx_host),
            );
        }
        # Failures the summary counts but no detail names stay visible instead of vanishing.
        add(
            "unspecified",
            0,
            max(
                0,
                session_count(summary["total-failure-session-count"] if summary else None)
                    - detailed,
            ),
            mx_host,
        );
        if produced {
            record_count += 1;
        }
    }
    if owned == 0 and top["policies"].length > 0 {
        raise ReportError("rejected", "Domain mismatch");
    }
    if not rows {
        raise ReportError("failed", "The report has no usable policies");
    }
    ordered = sorted(
        rows.values(), key=lambda (row: any) -> any { -(row["success"] + row["failure"]) }
    );
    return {
        "reporterOrg": reporter_org,
        "reporterEmail": json_text(top["contact-info"], REPORT_LIMITS.email) or NULL,
        "reportId": report_id,
        "recordCount": record_count,
        "messageCount": message_count,
        **window_and_rows(begin, end, ordered),
    };
}

# ---- keys -----------------------------------------------------------------------

async def:priv sha256_hex(parts: list[any]) -> str {
    digest = await globalThis.crypto.subtle.digest(
        "SHA-256",
        new(globalThis.TextEncoder).encode(globalThis.Array.prototype.join.call(parts, "\x00")),
    );
    octets: list[any] = globalThis.Array.from(new(globalThis.Uint8Array, digest));
    return "".join([octet.toString(16).padStart(2, "0") for octet in octets]);
}

"""Identifies a placeholder row by the raw mail object, so a queue redelivery finds the row it left behind."""
def rawReportKey(rawR2Key: str) -> any {
    return sha256_hex(["dmarc-raw", rawR2Key]);
}

"""
Identifies a report, so the same one arriving twice (or a queue redelivery) conflicts. `reporter` is the verified
reporter's organisational domain, or the report's own org name when it is unverified, and whether it was verified
is part of the key: an unverified (forgeable) report can never take over a verified report's key.
"""
def reportKey(reporter: str, reportId: str, verified: bool, kind: any = None) -> any {
    return sha256_hex([
        "dmarc" if kind is None else kind,
        "verified" if verified else "unverified",
        reporter,
        reportId,
    ]);
}

"""Identifies one aggregate row within a day. Only verified reporters write rows, so `reporter` is the verified organisational domain and rows of different reporters never merge."""
def rowKey(reporter: str, row: any) -> any {
    return sha256_hex([
        row["sourceIp"],
        reporter,
        row["headerFrom"],
        row["disposition"],
        globalThis.String(row["dkimAligned"]),
        globalThis.String(row["spfAligned"]),
    ]);
}

"""Identifies one TLS-RPT row within a day; `reporter` is the verified organisational domain, as for `rowKey`."""
def tlsRowKey(reporter: str, row: any) -> any {
    return sha256_hex([
        "tls",
        row["policyType"],
        reporter,
        at(row, "mxHost", ""),
        row["resultType"],
    ]);
}
