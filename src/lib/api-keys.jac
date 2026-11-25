import from "bcryptjs" { default as bcrypt }
import from "nanoid" { customAlphabet }

glob:priv ENC: any = new(globalThis.TextEncoder),
          ALNUM = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
          secret16: any = customAlphabet(ALNUM, 16);

"""Lowercase hex SHA-256 of an API key or app password."""
async def hashApiKey(fullKey: any) -> str {
    digest = await globalThis.crypto.subtle.digest("SHA-256", ENC.encode(fullKey));
    return "".join([b.toString(16).padStart(2, "0") for b in new(globalThis.Uint8Array, digest)]);
}

"""Constant-time compare for equal-length hashes; a length mismatch fails closed (hashes are fixed width)."""
def timingSafeEqualText(left: any, right: any) -> bool {
    (a, b, diff) = (ENC.encode(left), ENC.encode(right), 0);
    if a.length != b.length {
        return False;
    }
    for i in range(a.length) {
        diff |= a[i] ^ b[i];
    }
    return diff == 0;
}

# High-entropy secrets: SHA-256 is the verifier and `key_hash` repeats it (NOT NULL); bcrypt here
# would blow the Workers free-tier CPU limit. The prefix of an `ep_` key is its first 12 characters.
async def:priv issue(fullKey: any) -> any {
    (sha, prefix) = (await hashApiKey(fullKey), apiKeyLookupPrefix(fullKey));
    return {"fullKey": fullKey, "prefix": prefix, "hash": sha, "sha256": sha};
}

async def generateApiKey -> any {
    return await issue(f"ep_{newId()}");
}

"""Stored lookup prefix for a presented key: short app passwords keep fewer plaintext characters."""
def apiKeyLookupPrefix(key: any) -> any {
    return key.slice(0, 6 if key.length <= 16 else 12);
}

"""16-character password for mail apps. Older, longer `ep_` keys keep working."""
async def generateAppPassword -> any {
    return await issue(secret16());
}

"""bcrypt check for API keys from before `key_sha256` (not passwords); non-bcrypt hashes fail early."""
def verifyApiKey(fullKey: any, stored: any) -> bool {
    return stored.startsWith("$2") and bcrypt.compareSync(fullKey, stored);
}

def parseScopes(scopesJson: any) -> list[any] {
    try {
        parsed: any = globalThis.JSON.parse(scopesJson);
    } except Exception {
        return [];
    }
    return [s for s in parsed if isinstance(s, str)] if globalThis.Array.isArray(parsed) else [];
}

def scopesToJson(scopes: any) -> any {
    return globalThis.JSON.stringify(scopes);
}
