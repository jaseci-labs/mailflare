import from "drizzle-orm" { eq }
import from "zod" { z }

glob SPAM_SETTINGS_ID: str = "default",
     MAX_SPAM_BRANDS: int = 100,
     spamBrandSchema: any = z.object({
         "name": z.string().trim().min(2).max(60),
         "domains": z.array(
             z.string().trim().toLowerCase().regex(rx(r"^(?=.{3,253}$)[a-z0-9-]+(\.[a-z0-9-]+)+$"))
         ).min(1).max(20),
     });

"""Null until migration 0070 adds the columns, so spam analysis keeps running on env vars alone."""
async def:priv read_stored_settings(env: any) -> any {
    try {
        rows = await getDb(env).select({
            "spamhausDqsKey": appSettings.spamhausDqsKey,
            "abusechAuthKey": appSettings.abusechAuthKey,
            "spamDomainAgeCheck": appSettings.spamDomainAgeCheck,
            "spamBrands": appSettings.spamBrands,
        }).from(appSettings).where(eq(appSettings.id, SPAM_SETTINGS_ID)).limit(1);
        return rows[0]
            if rows.length
            else {
                "spamhausDqsKey": NULL,
                "abusechAuthKey": NULL,
                "spamDomainAgeCheck": True,
                "spamBrands": NULL,
            };
    } except Exception {
        return NULL;
    }
}

"""A stored setting, None where nothing is stored."""
def:priv saved(stored: any, name: str) -> any {
    return at(stored, name) if stored else None;
}

def:priv parse_brands(value: any) -> any {
    if not value {
        return [];
    }
    try {
        parsed = z.array(spamBrandSchema).safeParse(globalThis.JSON.parse(value));
        return parsed.data if parsed.success else [];
    } except Exception {
        return [];
    }
}

def:priv trimmed(value: any) -> any {
    return value.trim() if value else None;
}

def:priv env_flag_off(value: any) -> bool {
    return bool(value) and value.trim().toLowerCase() == "off";
}

async def getSpamIntelligenceConfig(env: any) -> dict[str, any] {
    stored = await read_stored_settings(env);
    return {
        "spamhausDqsKey": saved(stored, "spamhausDqsKey")
            or trimmed(at(env, "SPAMHAUS_DQS_KEY"))
            or None,
        "abuseChAuthKey": saved(stored, "abusechAuthKey")
            or trimmed(at(env, "ABUSECH_AUTH_KEY"))
            or None,
        "domainAge": either(saved(stored, "spamDomainAgeCheck"), True)
            and not env_flag_off(at(env, "SPAM_DOMAIN_AGE_CHECK")),
        "brands": parse_brands(saved(stored, "spamBrands")),
    };
}

async def getSpamIntelligenceStatus(env: any) -> dict[str, any] {
    stored = await read_stored_settings(env);

    def source(name: str, variable: str) -> any {
        return "settings" if saved(stored, name) else "env" if trimmed(at(env, variable)) else NULL;
    }
    return {
        "available": stored is not NULL,
        "spamhaus": {"source": source("spamhausDqsKey", "SPAMHAUS_DQS_KEY")},
        "abusech": {"source": source("abusechAuthKey", "ABUSECH_AUTH_KEY")},
        "domainAge": either(saved(stored, "spamDomainAgeCheck"), True),
        "domainAgeForcedOff": env_flag_off(at(env, "SPAM_DOMAIN_AGE_CHECK")),
        "brands": parse_brands(saved(stored, "spamBrands")),
    };
}

async def saveSpamIntelligenceSettings(env: any, values: any) {
    changes: dict[str, any] = {"updatedAt": new(globalThis.Date)};
    for name in ["spamhausDqsKey", "abusechAuthKey", "spamDomainAgeCheck"] {
        if values[name] is not None {
            changes[name] = values[name];
        }
    }
    brands = values["spamBrands"];
    if brands is not None {
        changes["spamBrands"] = globalThis.JSON.stringify(brands) if brands.length else NULL;
    }
    await getDb(env).insert(appSettings).values({
        "id": SPAM_SETTINGS_ID,
        **changes,
    }).onConflictDoUpdate({"target": appSettings.id, "set": changes});
}

"""
Spamhaus answers its permanent test entry 127.0.0.2 with a listing for any working key; an unknown key gets
no answer and a blocked one an error code in 127.255.255.0/24.
"""
async def checkSpamhausKey(key: str) -> bool {
    answers = await queryDns(f"2.0.0.127.{key}.zen.dq.spamhaus.net", "A");
    return any([answer.startsWith("127.0.0.") and answer != "127.0.0.1" for answer in answers]);
}

"""abuse.ch rejects an unknown Auth-Key with 401; any other answer means the key was accepted."""
async def checkAbuseChKey(key: str) -> bool {
    response = await globalThis.fetch(
        "https://urlhaus-api.abuse.ch/v1/host/",
        {
            "method": "POST",
            "headers": {"Auth-Key": key, "Content-Type": "application/x-www-form-urlencoded"},
            "body": new(globalThis.URLSearchParams, {"host": "example.com"}),
        },
    );
    if response.status in [401, 403] {
        return False;
    }
    if not response.ok {
        raise new(globalThis.Error, "abuse.ch answered " + globalThis.String(response.status));
    }
    return True;
}
