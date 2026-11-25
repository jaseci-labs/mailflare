import from "drizzle-orm" { eq }

"""Regions where SES can receive mail (SES inbound is not offered everywhere)."""
glob SES_RECEIVING_REGIONS: list[str] = [
    "us-east-1",
    "us-east-2",
    "us-west-2",
    "ap-south-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "ap-northeast-1",
    "ca-central-1",
    "eu-central-1",
    "eu-west-1",
    "eu-west-2",
    "sa-east-1",
    "us-gov-west-1",
];

glob:priv REGION_PATTERN: any = rx(r"^[a-z]{2}(-gov)?-[a-z]+-\d$");

def isValidRegion(region: any) -> bool {
    return REGION_PATTERN.test(region);
}

"""`o?.k`: undefined of a missing record."""
def:priv opt(o: any, k: str) -> any {
    return None if nil(o) else getattr(o, k, None);
}

"""The app_settings JSON: { accessKeyId?, secretAccessKey?, region?, accountId? }, or null."""
async def:priv read_stored(env: any) -> any {
    rows = await getDb(env).select({"awsConfig": appSettings.awsConfig}).from(appSettings).where(
        eq(appSettings.id, "default")
    ).limit(1);
    saved = opt(rows[0], "awsConfig") if rows else None;
    if not saved {
        return NULL;
    }
    try {
        return globalThis.JSON.parse(saved);
    } except Exception {
        return NULL;
    }
}

def:priv credentials(access_key_id: any, secret_access_key: any, region: any) -> any {
    if access_key_id and secret_access_key and region {
        return {
            "accessKeyId": access_key_id,
            "secretAccessKey": secret_access_key,
            "region": region,
        };
    }
    return NULL;
}

"""The saved AWS credentials, falling back to AWS_* environment variables."""
def:priv resolve(env: any, stored: any) -> any {
    trimmed = lambda (value: any) -> any { None if nil(value) else value.trim() };
    return credentials(
        opt(stored, "accessKeyId"), opt(stored, "secretAccessKey"), opt(stored, "region")
    )
        or credentials(
            trimmed(opt(env, "AWS_ACCESS_KEY_ID")),
            trimmed(opt(env, "AWS_SECRET_ACCESS_KEY")),
            trimmed(either(opt(env, "AWS_REGION"), opt(env, "AWS_DEFAULT_REGION"))),
        );
}

async def getAwsConfig(env: any) -> any {
    return resolve(env, await read_stored(env));
}

async def requireAwsConfig(env: any) -> any {
    config = await getAwsConfig(env);
    if not config {
        raise new(globalThis.Error, "AWS is selected but no credentials are configured");
    }
    return config;
}

async def getAwsConfigStatus(env: any) -> dict[str, any] {
    stored = await read_stored(env);
    config = await getAwsConfig(env);
    if not config {
        return {
            "configured": False,
            "source": NULL,
            "region": NULL,
            "accessKeyHint": NULL,
            "accountId": NULL,
        };
    }
    return {
        "configured": True,
        "source": "settings" if opt(stored, "accessKeyId") else "environment",
        "region": config["region"],
        "accessKeyHint": config["accessKeyId"].slice(-4),
        "accountId": either(opt(stored, "accountId"), NULL),
    };
}

async def saveAwsConfig(env: any, config: any, accountId: str) {
    values = {
        "awsConfig": globalThis.JSON.stringify(merged(config, {"accountId": accountId})),
        "updatedAt": new(globalThis.Date),
    };
    await getDb(env).insert(appSettings).values(
        merged({"id": "default"}, values)
    ).onConflictDoUpdate(record({"target": appSettings.id, "set": record(values)}));
}

async def clearAwsConfig(env: any) {
    await getDb(env).update(appSettings).set(
        record({"awsConfig": NULL, "updatedAt": new(globalThis.Date)})
    ).where(eq(appSettings.id, "default"));
}
