def:priv text(v: any) -> any {
    t: any = sub(v, rx(r"[\x00-\x1f\x7f]", "g"), " ").trim() if isinstance(v, str) else "";
    return t.slice(0, 800) or NULL;
}

def:priv pick(o: any, paths: str) -> any {
    return first([v for v in [dig(o, p.split(".")) for p in paths.split()] if not nil(v)]);
}

def agentProviderErrorMessage(error: any) -> str {
    d = error if is_object(error) else NULL;
    b = pick(d, "responseBody cause.responseBody data");
    try {
        b = globalThis.JSON.parse(b) if isinstance(b, str) else b;
    } except Exception {
        b = NULL;
    }
    s = either(pick(d, "statusCode cause.statusCode"), dig(b, ["error", "code"]));
    ok = globalThis.Number.isFinite(s) or isinstance(s, str) and rx(r"^[45]\d\d$").test(s);
    code = globalThis.Number(s) if ok and 400 <= globalThis.Number(s) < 600 else NULL;
    vs = [dig(b, p.split(".")) for p in "error.metadata.raw error.message error message".split()];
    msg = first([t for t in [text(v) for v in vs + [dig(d, ["message"]), error]] if t]);
    if (not msg or msg == "Provider returned error") and code == 429 {
        return "The AI provider is temporarily rate-limited. Retry shortly or choose another model.";
    }
    said = f"AI provider error {code}: {msg}" if code else msg;
    return said if msg else "The assistant could not finish this request";
}
