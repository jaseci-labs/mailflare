glob:priv enc: any = globalThis.encodeURIComponent;

def:priv records(zoneId: any, rest: str = "") -> str {
    return "/zones/" + globalThis.String(zoneId) + "/dns_records" + rest;
}

def:priv send(method: str, body: any) -> any {
    return {"method": method, "body": globalThis.JSON.stringify(body)};
}

def listMxRecords(env: any, zoneId: any, hostname: any) -> any {
    return cfRequest(env, records(zoneId, f"?type=MX&name={enc(hostname)}&per_page=5000"));
}

async def listDnsRecords(env: any, zoneId: any, params: any) -> any {
    query = f"?type={enc(params['type'])}&name={enc(params['name'])}&per_page=5000";
    return await cfRequest(env, records(zoneId, query));
}

async def deleteDnsRecord(env: any, zoneId: any, recordId: any) {
    await cfRequest(env, records(zoneId, "/" + globalThis.String(recordId)), {"method": "DELETE"});
}

async def createDnsRecord(env: any, zoneId: any, created: any) -> any {
    return await cfRequest(env, records(zoneId), send("POST", created));
}

"""Changes the content (and optionally the TTL) of a record in place; nothing else about it can be sent."""
async def updateDnsRecord(env: any, zoneId: any, recordId: any, changes: any) -> any {
    body = {"content": changes["content"]};
    if changes["ttl"] is not None {
        body["ttl"] = changes["ttl"];
    }
    path = records(zoneId, "/" + globalThis.String(recordId));
    return await cfRequest(env, path, send("PATCH", record(body)));
}
