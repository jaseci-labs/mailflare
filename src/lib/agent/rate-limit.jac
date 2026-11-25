async def allowAgentRequest(env: any, key: str) -> any {
    limiter = at(env, "AGENT_RATE_LIMIT");
    if not limiter {
        return True;
    }
    try {
        return (await limiter.limit(record({"key": key})))["success"];
    } except Exception {
        return False;
    }
}
