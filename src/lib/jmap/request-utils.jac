"""`decodeURIComponent` that reports a malformed escape (a bare `%`) as null instead of throwing."""
def tryDecodeURIComponent(value: str) -> any {
    try {
        return globalThis.decodeURIComponent(value);
    } except Exception {
        return NULL;
    }
}

"""EventSource poll interval in seconds: default 30, minimum 10, and never NaN or infinite."""
def parsePingSeconds(raw: any) -> any {
    value = globalThis.Number(raw or 30);
    return globalThis.Math.max(value, 10) if globalThis.Number.isFinite(value) else 30;
}
