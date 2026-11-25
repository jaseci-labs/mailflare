# Calendar tools that change or remove existing events; an assistant may only propose these.
glob CONFIRMED_CALENDAR_TOOLS: any = new(globalThis.Set, ["update_events", "delete_events"]);

glob:priv LIFETIME_MS: int = 15 * 60000,
          ENCODER: any = new(globalThis.TextEncoder);

"""The binary string is built in slices: spreading a large array into one call overflows the stack."""
def:priv base64url(data: any) -> str {
    binary = "";
    for i in range(0, data.length, 8192) {
        binary += globalThis.String.fromCharCode.apply(NULL, data.subarray(i, i + 8192));
    }
    return rx_sub(
        rx_sub(rx_sub(globalThis.btoa(binary), rx(r"\+", "g"), "-"), rx(r"\/", "g"), "_"),
        rx(r"=+$"),
        "",
    );
}

def:priv decoded(value: str) -> str {
    binary = globalThis.atob(rx_sub(rx_sub(value, rx("-", "g"), "+"), rx("_", "g"), "/"));
    return new(globalThis.TextDecoder).decode(
        globalThis.Uint8Array.from(binary, lambda (ch: any) -> int { ch.charCodeAt(0) })
    );
}

async def:priv mac(env: any, payload: str) -> str {
    key = await globalThis.crypto.subtle.importKey(
        "raw",
        ENCODER.encode(f"calendar-confirmation\n{await getServerSecret(env)}"),
        record({"name": "HMAC", "hash": "SHA-256"}),
        False,
        ["sign"],
    );
    signed = await globalThis.crypto.subtle.sign("HMAC", key, ENCODER.encode(payload));
    # The signature is carried as text: its bytes as characters, then UTF-8 and base64url like the payload.
    return base64url(
        ENCODER.encode(
            globalThis.String.fromCharCode.apply(NULL, new(globalThis.Uint8Array, signed))
        ),
    );
}

"""A token the signed-in user opens in the app to approve exactly this change; the model cannot redeem it."""
async def createCalendarConfirmation(
    env: any, userId: str, name: str, input: any, now: any = None
) -> str {
    issued = globalThis.Date.now() if now is None else now;
    payload = base64url(
        ENCODER.encode(
            globalThis.JSON.stringify(
                record({
                    "userId": userId,
                    "name": name,
                    "input": input,
                    "expiresAt": issued + LIFETIME_MS,
                }),
            ),
        ),
    );
    return f"{payload}.{await mac(env, payload)}";
}

async def readCalendarConfirmation(env: any, token: str, userId: str, now: any = None) -> any {
    current = globalThis.Date.now() if now is None else now;
    parts = token.split(".");
    if len(parts) < 2 or not parts[0] or not parts[1] {
        return NULL;
    }
    (payload, signature) = (parts[0], parts[1]);
    expected: any = await mac(env, payload);
    if len(expected) != len(signature) {
        return NULL;
    }
    # Compared in constant time: every character is read whether or not an earlier one differed.
    diff = 0;
    sig: any = signature;
    for index in range(len(expected)) {
        diff |= expected.charCodeAt(index) ^ sig.charCodeAt(index);
    }
    if diff != 0 {
        return NULL;
    }
    try {
        parsed = globalThis.JSON.parse(decoded(payload));
        if parsed["userId"] != userId
            or parsed["expiresAt"] < current
            or not CONFIRMED_CALENDAR_TOOLS.has(parsed["name"])
        {
            return NULL;
        }
        return parsed;
    } except Exception {
        return NULL;
    }
}
