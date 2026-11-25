type DnsAuthSummary = any;

type DnsStatusSummary = any;

def:priv kinds(records: any) -> any {
    return globalThis.Array.from(new(globalThis.Set, [r["type"] for r in records if r["type"]]));
}

def summariseDns(
    routingRecords: any,
    routingMissing: any,
    sendingRecords: any,
    routingEnabled: any = None,
    sendingEnabled: any = None,
    audit: any = None,
) -> any {
    enabled = False if routingEnabled is None else routingEnabled;
    routed = len(routingMissing) == 0 and (len(routingRecords) > 0 or enabled);
    sending = either(sendingEnabled, len(sendingRecords) > 0);
    summary = record({
        "routing": record({"configured": routed, "missing": kinds(routingMissing)}),
        "sending": record({"configured": sending, "records": kinds(sendingRecords)}),
    });
    summary["auth"] = record({k: audit[k]["status"] for k in "mx spf dkim dmarc".split()})
        if audit
        else None;
    return summary;
}
