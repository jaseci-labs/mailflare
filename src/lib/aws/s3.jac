glob:priv XMLNS: str = 'xmlns="http://s3.amazonaws.com/doc/2006-03-01/"';

# A request to the bucket's host (the service's own without a bucket), for the object at `key`.
async def:priv on(c: any, bucket: str, m: any = None, key: any = None, **kw: any) -> any {
    h = (f"{bucket}." if bucket else "") + f"s3.{c['region']}.amazonaws.com";
    kw["path"] = "/" + "/".join([globalThis.encodeURIComponent(s) for s in (key or "").split("/")]);
    return await awsRequest({"config": c, "service": "s3", "host": h, "method": m, **kw});
}

async def listBuckets(config: any) {
    await on(config, "");
}

async def bucketExists(config: any, bucket: str) -> bool {
    return await awsSpare(on(config, bucket, "HEAD"), status=404) is not None;
}

async def createBucket(config: any, bucket: str) {
    region = config["region"];
    xml = f"<CreateBucketConfiguration {XMLNS}><LocationConstraint>{region}</LocationConstraint>";
    body = "" if region == "us-east-1" else xml + "</CreateBucketConfiguration>";
    await awsSpare(on(config, bucket, "PUT", body=body), "BucketAlreadyOwnedByYou");
}

async def putBucketPolicy(config: any, bucket: str, policy: any) {
    (json, hs) = (globalThis.JSON.stringify(policy), {"Content-Type": "application/json"});
    await on(config, bucket, "PUT", query={"policy": ""}, body=json, headers=hs);
}

"""Expires leftover raw messages; best effort, since we delete each object after intake."""
async def putExpiryLifecycle(config: any, bucket: str, prefix: str, days: any) {
    r = f"<ID>mailflare-expire-inbound</ID><Filter><Prefix>{prefix}</Prefix></Filter>";
    r = f"<Rule>{r}<Status>Enabled</Status><Expiration><Days>{days}</Days></Expiration></Rule>";
    body = f"<LifecycleConfiguration {XMLNS}>{r}</LifecycleConfiguration>";
    x: any = await sha256Hex(body);
    sha = globalThis.btoa("".join([chr(int(b, 16)) for b in x.match(rx("..", "g"))]));
    hs = {"Content-Type": "application/xml", "x-amz-sdk-checksum-algorithm": "SHA256"};
    hs["x-amz-checksum-sha256"] = sha;
    await on(config, bucket, "PUT", query={"lifecycle": ""}, body=body, headers=hs);
}

async def getObject(config: any, bucket: str, key: str) -> any {
    return await (await on(config, bucket, key=key)).arrayBuffer();
}

async def deleteObject(config: any, bucket: str, key: str) {
    await on(config, bucket, "DELETE", key);
}
