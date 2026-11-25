glob:priv STATES: any = "active invalid expired deactivated".split(),
          BAD: str = "Paymug returned an invalid license response",
          arr: any = globalThis.Array.isArray;

async def hashLicenseKey(licenseKey: any) -> str {
    d = await globalThis.crypto.subtle.digest(
        "SHA-256", new(globalThis.TextEncoder).encode(licenseKey)
    );
    return "".join([b.toString(16).padStart(2, "0") for b in [*new(globalThis.Uint8Array, d)]]);
}

def:priv strings(vs: any) -> any {
    return [v for v in vs if isinstance(v, str)];
}

def:priv text(v: any) -> any {
    return v if isinstance(v, str) else None;
}

def parseFeatures(value: any) -> any {
    try {
        p = globalThis.JSON.parse(value);
        return strings(p) if arr(p) else [];
    } except Exception {
        return [];
    }
}

def parsePaymugLicenseResponse(v: any = None) -> any {
    if not is_object(v) or not isinstance(v["valid"], bool) or not STATES.includes(v["state"]) {
        raise new(globalThis.Error, BAD);
    }
    s = v["seatLimit"];
    seats = s if s is NULL or globalThis.Number.isInteger(s) and s >= 0 else None;
    out = {k: text(v[k]) for k in ["instanceId", "productId", "plan"]};
    f = strings(v["features"]) if arr(v["features"]) else None;
    return merged(
        out, {"valid": v["valid"], "state": v["state"], "features": f, "seatLimit": seats}
    );
}

def normalizeLicensePlan(productId: any = None, plan: any = None) -> any {
    ids = LICENSE_PRODUCT_IDS;
    if productId {
        return "pro" if productId == ids["pro"] else ("team" if productId == ids["team"] else NULL);
    }
    n = plan.trim().toLowerCase() if plan else None;
    return n if n in ["pro", "team"] else NULL;
}
