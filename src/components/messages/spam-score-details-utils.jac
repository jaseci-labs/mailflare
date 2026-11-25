def:priv is_signal(s: any) -> bool {
    texts = isinstance(at(s, "id"), str) and isinstance(at(s, "reason"), str);
    return is_object(s) and texts and globalThis.Number(at(s, "score")) is at(s, "score");
}

def parseSpamSignals(value: any = None) -> any {
    try {
        result = globalThis.JSON.parse(value) if value else [];
    } except Exception {
        return [];
    }
    return [s for s in result if is_signal(s)] if globalThis.Array.isArray(result) else [];
}
