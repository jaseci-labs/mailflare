"""Whether `limiter` lets this client through under `prefix`; no limiter, or a broken one, lets everyone through.

Limits are keyed by the resolved client IP. Without a per-client key every visitor lands in one shared
"unknown" bucket and scanners can lock out legitimate logins; trusting raw forwarding headers here
would be worse: a client could rotate them to leave the bucket entirely."""
async def:priv allowed(limiter: any, prefix: str, request: any, label: str) -> any {
    if not limiter {
        return True;
    }
    try {
        key = prefix + either(getClientIp(request), "unknown");
        return (await limiter.limit(record({"key": key})))["success"];
    } except Exception as error {
        globalThis.console.warn(f"{label} rate limiter unavailable", error);
        return True;
    }
}

"""Mobile sign-ins have their own, stricter budget (they skip Turnstile)."""
async def allowDeviceLoginAttempt(env: any, request: any) -> any {
    limiter = either(at(env, "DEVICE_LOGIN_RATE_LIMIT"), at(env, "LOGIN_RATE_LIMIT"));
    return await allowed(limiter, "device:", request, "Device login");
}

"""Public booking submissions send mail from the host's address, so they get a per-client budget of their own."""
async def allowBookingAttempt(env: any, request: any) -> any {
    return await allowed(at(env, "LOGIN_RATE_LIMIT"), "booking:", request, "Booking");
}

async def allowLoginAttempt(env: any, request: any) -> any {
    return await allowed(at(env, "LOGIN_RATE_LIMIT"), "", request, "Login");
}
