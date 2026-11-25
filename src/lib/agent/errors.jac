glob:priv CTL: any = rx(r"[\u0000-\u001f\u007f]", "g"),
          HTTP: any = rx(r"^[45]\d\d$");

"""The first of the dotted `paths` of `o` (each read like `o?.a?.b`) that is not nullish, mapped by `f`."""
def:priv pick(o: any, paths: str, f: any = None) -> any {
    vs = [dig(o, p.split(".")) for p in paths.split()];
    return first([v for v in ([f(v) for v in vs] if f else vs) if not nil(v)]);
}

def:priv text(v: any) -> any {
    t: any = sub(v, CTL, " ").trim() if isinstance(v, str) else "";
    return t.slice(0, 800) if t else NULL;
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
    ok = globalThis.Number.isFinite(s) or isinstance(s, str) and HTTP.test(s);
    code = globalThis.Number(s) if ok and 400 <= globalThis.Number(s) < 600 else NULL;
    m = pick(b, "error.metadata.raw error.message error message", text);
    message = either(either(m, pick(d, "message", text)), text(error));
    if (not message or message == "Provider returned error") and code == 429 {
        return "The AI provider is temporarily rate-limited. Retry shortly or choose another model.";
    }
    if not message {
        return "The assistant could not finish this request";
    }
    return f"AI provider error {code}: {message}" if code else message;
}
