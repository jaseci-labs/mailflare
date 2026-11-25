import from "bcryptjs" { default as bcrypt }
import from "nanoid" { customAlphabet }

glob:priv ENCODER: any = new(globalThis.TextEncoder),
          APP_PASSWORD_LENGTH: int = 16,
          APP_PASSWORD_PREFIX_LENGTH: int = 6,
          app_password_secret: any = customAlphabet(
              "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", APP_PASSWORD_LENGTH
          );

"""Lowercase hex SHA-256 of an API key or app password."""
async def hashApiKey(fullKey: any) -> str {
    digest = await globalThis.crypto.subtle.digest("SHA-256", ENCODER.encode(fullKey));
    return "".join([
        byte.toString(16).padStart(2, "0")
        for byte in new(globalThis.Uint8Array, digest)
    ]);
}

"""Constant-time compare for equal-length hashes. A length mismatch fails closed; the hashes this stores are fixed width."""
def timingSafeEqualText(left: any, right: any) -> bool {
    (a, b) = (ENCODER.encode(left), ENCODER.encode(right));
    if a.length != b.length {
        return False;
    }
    diff = 0;
    for index in range(a.length) {
        diff |= a[index] ^ b[index];
    }
    return diff == 0;
}

async def:priv issue(fullKey: any, prefix: any) -> any {
    sha256 = await hashApiKey(fullKey);
    # These secrets are high-entropy. SHA-256 is the verifier, and `key_hash` repeats it so the
    # NOT NULL column stays a hash of the secret. bcrypt here would blow the Workers free-tier
    # CPU limit on the request that creates the key.
    return record({"fullKey": fullKey, "prefix": prefix, "hash": sha256, "sha256": sha256});
}

async def generateApiKey -> any {
    fullKey: any = f"ep_{newId()}";
    return await issue(fullKey, fullKey.slice(0, 12));
}

"""Stored lookup prefix for a presented key: short app passwords keep fewer plaintext characters."""
def apiKeyLookupPrefix(key: any) -> str {
    return key.slice(0, APP_PASSWORD_PREFIX_LENGTH if key.length <= APP_PASSWORD_LENGTH else 12);
}

"""16-character password for mail apps. Older, longer `ep_` keys keep working."""
async def generateAppPassword -> any {
    fullKey = app_password_secret();
    return await issue(fullKey, apiKeyLookupPrefix(fullKey));
}

"""
bcrypt check for API keys issued before `key_sha256` existed. Human passwords go through
`verifyPassword` and are not handled here. Non-bcrypt values return false without calling into bcrypt.
"""
def verifyApiKey(fullKey: any, stored: any) -> bool {
    return stored.startsWith("$2") and bcrypt.compareSync(fullKey, stored);
}

def parseScopes(scopesJson: any) -> list[any] {
    try {
        parsed = globalThis.JSON.parse(scopesJson);
    } except Exception {
        return [];
    }
    return [s for s in parsed if isinstance(s, str)] if globalThis.Array.isArray(parsed) else [];
}

def scopesToJson(scopes: any) -> str {
    return globalThis.JSON.stringify(scopes);
}
