glob:priv XMLNS = 'xmlns="http://s3.amazonaws.com/doc/2006-03-01/"';

"""A request to the bucket's own host; `more` adds method, path, query, body and headers."""
async def:priv bucket_request(config: any, bucket: str, more: any = None) -> any {
    return await awsRequest(
        merged(
            {
                "config": config,
                "service": "s3",
                "host": f"{bucket}.s3.{config['region']}.amazonaws.com",
            },
            either(more, {}),
        ),
    );
}

def:priv object_path(key: str) -> str {
    return "/" + "/".join([globalThis.encodeURIComponent(part) for part in key.split("/")]);
}

"""The error as it was thrown: Jac hands `except` a wrapper of a JavaScript error, the original in `js`."""
def:priv thrown(caught: any) -> any {
    return getattr(caught, "js", caught);
}

def:priv is_aws_error(error: any, field: str, value: any) -> bool {
    return isinstance(error, AwsError) and getattr(error, field) == value;
}

async def listBuckets(config: any) {
    await awsRequest({
        "config": config,
        "service": "s3",
        "host": f"s3.{config['region']}.amazonaws.com",
    });
}

async def bucketExists(config: any, bucket: str) -> bool {
    try {
        await bucket_request(config, bucket, {"method": "HEAD"});
        return True;
    } except Exception as caught {
        if is_aws_error(thrown(caught), "status", 404) {
            return False;
        }
        raise thrown(caught);
    }
}

async def createBucket(config: any, bucket: str) {
    region = config["region"];
    body = ""
        if region == "us-east-1"
        else f"<CreateBucketConfiguration {XMLNS}><LocationConstraint>{region}</LocationConstraint></CreateBucketConfiguration>";
    try {
        await bucket_request(config, bucket, {"method": "PUT", "body": body});
    } except Exception as caught {
        if not is_aws_error(thrown(caught), "code", "BucketAlreadyOwnedByYou") {
            raise thrown(caught);
        }
    }
}

async def putBucketPolicy(config: any, bucket: str, policy: any) {
    await bucket_request(
        config,
        bucket,
        {
            "method": "PUT",
            "query": {"policy": ""},
            "body": globalThis.JSON.stringify(policy),
            "headers": {"Content-Type": "application/json"},
        },
    );
}

"""Expires leftover raw messages; best effort, since we delete each object after intake."""
async def putExpiryLifecycle(config: any, bucket: str, prefix: str, days: any) {
    body = f"<LifecycleConfiguration {XMLNS}><Rule><ID>mailflare-expire-inbound</ID><Filter><Prefix>{prefix}</Prefix></Filter><Status>Enabled</Status><Expiration><Days>{days}</Days></Expiration></Rule></LifecycleConfiguration>";
    digest: str = await sha256Hex(body);
    octets = "".join([
        globalThis.String.fromCharCode(globalThis.parseInt(digest[i:i + 2], 16))
        for i in range(0, len(digest), 2)
    ]);
    await bucket_request(
        config,
        bucket,
        {
            "method": "PUT",
            "query": {"lifecycle": ""},
            "body": body,
            "headers": {
                "Content-Type": "application/xml",
                "x-amz-sdk-checksum-algorithm": "SHA256",
                "x-amz-checksum-sha256": globalThis.btoa(octets),
            },
        },
    );
}

async def getObject(config: any, bucket: str, key: str) -> any {
    response = await bucket_request(config, bucket, {"path": object_path(key)});
    return await response.arrayBuffer();
}

async def deleteObject(config: any, bucket: str, key: str) {
    await bucket_request(config, bucket, {"method": "DELETE", "path": object_path(key)});
}
