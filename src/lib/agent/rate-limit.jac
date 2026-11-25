async def allowAgentRequest(env: any, key: str) -> any {
    limiter = at(env, "AGENT_RATE_LIMIT");
    try {
        return (await limiter.limit(record({"key": key})))["success"] if limiter else True;
    } except Exception {
        return False;
    }
}
