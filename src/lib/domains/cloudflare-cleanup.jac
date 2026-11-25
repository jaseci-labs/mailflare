async def deleteEmailRoutingRulesForDomain(env: any, zoneId: any, hostname: any) {
    if zoneId == "manual" {
        return;
    }
    host = hostname.toLowerCase();
    def to_domain(m: any) -> bool {
        value = m["value"] if m["type"] == "literal" and m["field"] == "to" else None;
        low: any = value.toLowerCase() if globalThis.Boolean(value) else "";
        return bool(globalThis.Boolean(value)) and (low == host or bool(low.endsWith("@" + host)));
    }
    rules = await listEmailRoutingRules(env, zoneId);
    linked = rules.filter(
        lambda (r: any) -> bool { bool(either(r["matchers"], []).some(to_domain)) }
    );
    ids = [either(r["id"], r["tag"]) for r in linked];
    await globalThis.Promise.all([deleteEmailRoutingRule(env, zoneId, i) for i in ids if i]);
}
