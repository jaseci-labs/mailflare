glob:priv STATES: any = ["active", "invalid", "expired", "deactivated"],
          INVALID: str = "Paymug returned an invalid license response";

async def hashLicenseKey(licenseKey: any) -> str {
    digest = await globalThis.crypto.subtle.digest(
        "SHA-256", new(globalThis.TextEncoder).encode(licenseKey)
    );
    return "".join([
        byte.toString(16).padStart(2, "0")
        for byte in list(new(globalThis.Uint8Array, digest))
    ]);
}

def:priv strings(values: any) -> list[str] {
    return [value for value in values if isinstance(value, str)];
}

def parseFeatures(value: any) -> list[str] {
    try {
        parsed = globalThis.JSON.parse(value);
        return strings(parsed) if globalThis.Array.isArray(parsed) else [];
    } except Exception {
        return [];
    }
}

def parsePaymugLicenseResponse(value: any = None) -> any {
    if not value or globalThis.Object(value) is not value or callable(value) {
        raise new(globalThis.Error, INVALID);
    }
    if not isinstance(value["valid"], bool) or not STATES.includes(value["state"]) {
        raise new(globalThis.Error, INVALID);
    }
    def text(v: any) -> any {
        return v if isinstance(v, str) else None;
    }
    seats = value["seatLimit"];
    return merged({
        "valid": value["valid"],
        "state": value["state"],
        "instanceId": text(value["instanceId"]),
        "productId": text(value["productId"]),
        "plan": text(value["plan"]),
        "features": strings(value["features"])
            if globalThis.Array.isArray(value["features"])
            else None,
        "seatLimit": seats
            if seats is NULL or (globalThis.Number.isInteger(seats) and seats >= 0)
            else None,
    });
}

def normalizeLicensePlan(productId: any = None, plan: any = None) -> any {
    if productId {
        return "pro"
            if productId == LICENSE_PRODUCT_IDS["pro"]
            else ("team" if productId == LICENSE_PRODUCT_IDS["team"] else NULL);
    }
    normalized = None if nil(plan) else plan.trim().toLowerCase();
    return normalized if normalized in ["pro", "team"] else NULL;
}
