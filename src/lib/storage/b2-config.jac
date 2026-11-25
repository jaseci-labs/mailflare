glob:priv S3_HELP: str = """AWS S3 needs S3_BUCKET, S3_REGION and credentials (S3_ACCESS_KEY_ID and
S3_SECRET_ACCESS_KEY, or AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY).""";

"""The first of `names` that is set (`??`), trimmed."""
def:priv setting(env: any, names: str) -> any {
    found = first([at(env, n) for n in names.split() if not nil(at(env, n))]);
    return None if found is None else found.trim();
}

"""Accepts `s3.us-west-004.backblazeb2.com` with or without a scheme or trailing slash."""
def normalizeB2Endpoint(value: any) -> str {
    return sub(rx_sub(value.trim(), rx(r"^https?:\/\/", "i"), ""), rx(r"\/+$"), "").toLowerCase();
}

def b2RegionFromEndpoint(endpoint: any) -> any {
    found = rx(r"^s3\.([a-z0-9-]+)\.backblazeb2\.com$").exec(endpoint);
    return found[1] if found else NULL;
}

# Backblaze B2 settings from the Worker environment (B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET,
# B2_ENDPOINT); null when any is missing, which leaves the R2 binding (or local files) in use.
def getB2Config(env: any) -> any {
    (key_id, app_key) = (setting(env, "B2_KEY_ID"), setting(env, "B2_APPLICATION_KEY"));
    bucket = setting(env, "B2_BUCKET");
    endpoint = normalizeB2Endpoint(env.B2_ENDPOINT) if at(env, "B2_ENDPOINT") else "";
    region = b2RegionFromEndpoint(endpoint) if key_id and app_key and bucket and endpoint else NULL;
    found = {"keyId": key_id, "applicationKey": app_key, "bucket": bucket, "endpoint": endpoint};
    return {**found, "region": region} if region else NULL;
}

# AWS S3 settings: S3_BUCKET and S3_REGION, with S3_ACCESS_KEY_ID / S3_SECRET_ACCESS_KEY falling
# back to the AWS_* variables the SES integration already uses. Backblaze wins when both are set.
def getS3Config(env: any) -> any {
    bucket = setting(env, "S3_BUCKET");
    region = setting(env, "S3_REGION AWS_REGION AWS_DEFAULT_REGION");
    key_id = setting(env, "S3_ACCESS_KEY_ID AWS_ACCESS_KEY_ID");
    app_key = setting(env, "S3_SECRET_ACCESS_KEY AWS_SECRET_ACCESS_KEY");
    known = bool(region) and rx(r"^[a-z]{2}(-gov|-iso[a-z]?)?-[a-z]+-\d$").test(region);
    if not (bucket and key_id and app_key and known) {
        return NULL;
    }
    found = {"keyId": key_id, "applicationKey": app_key, "bucket": bucket, "region": region};
    return {**found, "endpoint": f"s3.{region}.amazonaws.com"};
}

"""The S3-compatible bucket in use, if any."""
def getObjectStorageConfig(env: any) -> any {
    (b2, s3) = (getB2Config(env), getS3Config(env));
    return {**b2, "provider": "backblaze"} if b2 else {**s3, "provider": "s3"} if s3 else NULL;
}

def getStorageStatus(env: any) -> any {
    c = getObjectStorageConfig(env);
    local = "files" if at(env, "MAILFLARE_RUNTIME") == "node" else "r2";
    out = {"provider": c["provider"] if c else local, "configured": True};
    return {**out, "bucket": c["bucket"] if c else NULL, "endpoint": c["endpoint"] if c else NULL};
}

"""Names the variables that are set without exposing values, to diagnose a half-finished setup."""
def describeB2Problem(env: any) -> any {
    b2 = [at(env, n) for n in "B2_KEY_ID B2_APPLICATION_KEY B2_BUCKET B2_ENDPOINT".split()];
    if not getB2Config(env) and not any(b2) and at(env, "S3_BUCKET") and not getS3Config(env) {
        return S3_HELP.replace("\n", " ");
    }
    present = len([v for v in b2 if v and v.trim()]);
    msg = "Backblaze B2 needs B2_KEY_ID, B2_APPLICATION_KEY, B2_BUCKET and B2_ENDPOINT together.";
    msg = msg if present < 4 else "B2_ENDPOINT must look like s3.us-west-004.backblazeb2.com.";
    return NULL if present == 0 or getB2Config(env) or getS3Config(env) else msg;
}
