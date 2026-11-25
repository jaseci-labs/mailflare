glob PAYMUG_BASE_URL: str = "https://app.paymug.co";

def:priv refusal(status: int) -> str {
    if status == 409 {
        return "This license is active on another installation. Deactivate it there before retrying.";
    }
    if status in [401, 403] {
        return "Paymug rejected this license key.";
    }
    if status >= 500 {
        return "Paymug is temporarily unavailable. Try again later.";
    }
    return "Paymug could not process this license request.";
}

async def callPaymugLicenseApi(action: any, input: any) -> any {
    try {
        response = await globalThis.fetch(
            PAYMUG_BASE_URL + "/api/v1/licenses/" + globalThis.String(action),
            record({
                "method": "POST",
                "headers": record({"Content-Type": "application/json"}),
                "body": globalThis.JSON.stringify(input),
                "signal": globalThis.AbortSignal.timeout(15000),
            }),
        );
    } except Exception {
        raise new(globalThis.Error, "Unable to reach Paymug. Try again later.");
    }
    if not response.ok {
        raise new(globalThis.Error, refusal(response.status));
    }
    try {
        return parsePaymugLicenseResponse(await response.json());
    } except Exception {
        raise new(globalThis.Error, "Paymug returned an invalid license response");
    }
}
