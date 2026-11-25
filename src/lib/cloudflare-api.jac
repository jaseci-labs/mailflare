type CfDnsRecord = any;

type EmailRoutingRuleCache = any;

glob:priv PER_PAGE: int = 50,
          MAX_PAGES: int = 100,
          DELETE: any = {"method": "DELETE"};

def:priv truthy(v: any) -> bool {
    return bool(globalThis.Boolean(v));
}

def:priv send(method: str, body: any) -> any {
    return {"method": method, "body": globalThis.JSON.stringify(record(body))};
}

def:priv js(v: any) -> str {
    return globalThis.String(v);
}

def:priv z(*parts: any) -> str {
    return "/zones/" + "".join([js(p) for p in parts]);
}

def:priv fail(msg: str, status: any, path: any, errors: any) {
    e = CloudflareApiError(msg, status, path, errors);
    # Jac's raise sets `__cause__`: keep it out of the keys JavaScript sees, as in the original.
    globalThis.Object.defineProperty(e, "__cause__", record({"writable": True}));
    raise e;
}

def:priv find(xs: any, f: any) -> any {
    return globalThis.Reflect.get(xs, "find").call(xs, f);
}

"""`(result, result_info)` of a Cloudflare API call; any failure is a CloudflareApiError."""
async def:priv request(env: any, path: any, opts: any = None) -> any {
    auth = getCloudflareAuth(env);
    json_type = {"Content-Type": "application/json"};
    headers = merged(getCloudflareAuthHeaders(auth), json_type, dig(opts, ["headers"], {}));
    signal = globalThis.AbortSignal.timeout(30000);
    opts = merged({"signal": signal}, either(opts, {}), {"headers": headers});
    res = await globalThis.fetch(f"https://api.cloudflare.com/client/v4{path}", opts);
    # Cloudflare answers incidents with an HTML page; report it as an API error, not a parse error.
    json = await res.json().catch(lambda (e: any) -> any { NULL });
    (status, text) = (res.status, res.statusText);
    if not truthy(json) {
        msg: any = " ".join([js(x) for x in ["Cloudflare API", path, "returned", status, text]]);
        msg = msg + " without a JSON body";
        fail(msg.trim(), status, path, []);
    }
    if not truthy(json["success"]) {
        errors = either(json["errors"], []);
        msg = formatCloudflareError(path, status, text, errors)
            + getCloudflareAuthHint(errors, path);
        fail(msg, status, path, errors);
    }
    return (json["result"], json["result_info"]);
}

def cfRequest(env: any, path: any, opts: any = None) -> any {
    return promise(request(env, path, opts)).then(lambda (r: any) -> any { r[0] });
}

def getZone(env: any, zoneId: any) -> any {
    return cfRequest(env, z(zoneId));
}

async def findZoneByHostname(env: any, hostname: any) -> any {
    for c in getZoneLookupCandidates(hostname) {
        zones = await cfRequest(
            env, f"/zones?name={globalThis.encodeURIComponent(c)}&status=active"
        );
        zone = find(zones, lambda (z: any) -> bool { z["name"] == c });
        if not nil(zone) {
            return zone;
        }
    }
    return NULL;
}

async def getEmailRoutingDns(env: any, zoneId: any) -> any {
    result = await cfRequest(env, z(zoneId, "/email/routing/dns"));
    missing = [e["missing"] for e in either(result["errors"], []) if truthy(e["missing"])];
    return {"records": either(result["record"], []), "missing": missing};
}

def enableEmailRouting(env: any, zoneId: any, hostname: any = None) -> any {
    opts = send("POST", {"name": hostname}) if hostname else {"method": "POST"};
    return cfRequest(env, z(zoneId, "/email/routing/dns"), opts);
}

def disableEmailRouting(env: any, zoneId: any) -> any {
    return cfRequest(env, z(zoneId, "/email/routing/dns"), DELETE);
}

def listSendingSubdomains(env: any, zoneId: any) -> any {
    return cfRequest(env, z(zoneId, "/email/sending/subdomains"));
}

def createSendingSubdomain(env: any, zoneId: any, hostname: any) -> any {
    opts = send("POST", {"name": hostname});
    return cfRequest(env, z(zoneId, "/email/sending/subdomains"), opts);
}

def deleteSendingSubdomain(env: any, zoneId: any, tag: any) -> any {
    return cfRequest(env, z(zoneId, "/email/sending/subdomains/", tag), DELETE);
}

def getSendingSubdomainDns(env: any, zoneId: any, tag: any) -> any {
    return cfRequest(env, z(zoneId, "/email/sending/subdomains/", tag, "/dns"));
}

def getEmailRoutingSettings(env: any, zoneId: any) -> any {
    return cfRequest(env, z(zoneId, "/email/routing"));
}

"""Every routing rule of the zone, page by page. Throws at the page cap: callers decide from this
list whether a rule exists, and a partial list would make them create duplicates."""
async def listEmailRoutingRules(env: any, zoneId: any) -> any {
    rules: list[any] = [];
    for page in range(1, MAX_PAGES + 1) {
        path = z(zoneId, f"/email/routing/rules?page={page}&per_page={PER_PAGE}");
        (result, info) = await request(env, path);
        rules.extend(result);
        total = None if nil(info) else info["total_pages"];
        last = len(result) < PER_PAGE if total is None else page >= globalThis.Number(total);
        if last or len(result) == 0 {
            return rules;
        }
    }
    raise new(
        globalThis.Error,
        "Email routing rules for zone " + js(zoneId) + f" span more than {MAX_PAGES} pages",
    );
}

def deleteEmailRoutingRule(env: any, zoneId: any, ruleId: any) -> any {
    return cfRequest(env, z(zoneId, "/email/routing/rules/", ruleId), DELETE);
}

def:priv route(address: any, worker: str, name: any) -> any {
    to = record({"type": "literal", "field": "to", "value": address});
    action = record({"type": "worker", "value": [worker]});
    return {"actions": [action], "enabled": True, "matchers": [to], "name": name};
}

async def createEmailRoutingRuleToWorker(env: any, zoneId: any, address: any) -> any {
    worker = getEmailWorkerName(env);
    opts = send("POST", route(address, worker, "Route " + js(address) + " to " + worker));
    return await cfRequest(env, z(zoneId, "/email/routing/rules"), opts);
}

def:priv find_route(rules: any, address: str, worker: str) -> any {
    def to(m: any) -> bool {
        value = m["value"] if m["type"] == "literal" and m["field"] == "to" else None;
        return not nil(value) and value.toLowerCase() == address;
    }
    def runs(a: any) -> bool {
        return a["type"] == "worker"
            and (not dig(a, ["value", "length"]) or a["value"].includes(worker));
    }
    def is_route(r: any) -> bool {
        (routes, sends) = (
            truthy(either(r["matchers"], []).some(to)),
            either(r["actions"], []).some(runs),
        );
        return routes and truthy(sends);
    }
    return find(rules, is_route);
}

def:priv rules_cached(env: any, zoneId: any, cache: any) -> any {
    if not truthy(cache) {
        return promise(listEmailRoutingRules(env, zoneId));
    }
    listing = cache.get(zoneId);
    if nil(listing) {
        listing = promise(listEmailRoutingRules(env, zoneId));
        cache.set(zoneId, listing);
        # A failed listing must not stay cached for the next address.
        listing.catch(lambda (e: any) -> any { cache.delete(zoneId) });
    }
    return listing;
}

async def ensureEmailRoutingRuleToWorker(
    env: any, zoneId: any, address: any, changes: any = None, ruleCache: any = None
) -> any {
    if zoneId == "manual" {
        return None;
    }
    (low, worker) = (address.toLowerCase(), getEmailWorkerName(env));
    existing = find_route(await rules_cached(env, zoneId, ruleCache), low, worker);
    if truthy(dig(existing, ["enabled"])) {
        return existing;
    }
    if truthy(dig(existing, ["id"])) {
        if not nil(changes) {
            changes.push(
                record({"zoneId": zoneId, "ruleId": existing["id"], "previous": existing})
            );
        }
        body = route(low, worker, either(existing["name"], f"Route {low} to {worker}"));
        body["priority"] = existing["priority"];
        return await cfRequest(
            env, z(zoneId, "/email/routing/rules/", existing["id"]), send("PUT", body)
        );
    }
    created = await createEmailRoutingRuleToWorker(env, zoneId, low);
    if truthy(created["id"]) and not nil(changes) {
        changes.push(record({"zoneId": zoneId, "ruleId": created["id"]}));
    }
    return created;
}

"""Undo only the rules created or re-enabled by a failed provisioning attempt."""
async def rollbackEmailRoutingRuleChanges(env: any, changes: any) {
    def undo(c: any) -> any {
        (zone, rule, prev) = (c["zoneId"], c["ruleId"], c["previous"]);
        if not truthy(prev) {
            return deleteEmailRoutingRule(env, zone, rule);
        }
        body = {k: prev[k] for k in "actions enabled matchers name priority".split()};
        return cfRequest(env, z(zone, "/email/routing/rules/", rule), send("PUT", body));
    }
    results = await globalThis.Promise.allSettled([undo(c) for c in changes]);
    failures = [r.reason for r in results if r.status == "rejected"];
    if failures {
        raise new(globalThis.AggregateError, failures, "Unable to restore routing rules");
    }
}

async def deleteEmailRoutingRuleForAddress(env: any, zoneId: any, address: any) -> bool {
    if zoneId == "manual" {
        return False;
    }
    (low, worker) = (address.toLowerCase(), getEmailWorkerName(env));
    existing = find_route(await listEmailRoutingRules(env, zoneId), low, worker);
    if not truthy(dig(existing, ["id"])) {
        return False;
    }
    await deleteEmailRoutingRule(env, zoneId, existing["id"]);
    return True;
}
