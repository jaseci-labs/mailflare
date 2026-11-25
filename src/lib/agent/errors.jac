glob:priv CONTROL: any = rx(r"[\u0000-\u001f\u007f]", "g"),
          HTTP_ERROR: any = rx(r"^[45]\d\d$"),
          NOT_OBJECTS: list[str] = [
              "Null",
              "Undefined",
              "String",
              "Number",
              "Boolean",
              "Function",
              "Symbol",
              "BigInt",
          ];

def:priv kind(v: any) -> str {
    return globalThis.Object.prototype.toString.call(v).slice(8, -1);
}

"""`value` when it is an object (as `typeof` reads it: arrays too), else null."""
def:priv as_record(value: any) -> any {
    return NULL if kind(value) in NOT_OBJECTS else value;
}

"""`o?.k` of a record that may be null."""
def:priv field(o: any, k: str) -> any {
    return None if nil(o) else o[k];
}

def:priv readable_text(value: any) -> any {
    if kind(value) != "String" {
        return NULL;
    }
    text: any = rx_sub(value, CONTROL, " ");
    text = text.trim();
    return text.slice(0, 800) if text else NULL;
}

def:priv parse_response_body(value: any) -> any {
    if kind(value) != "String" {
        return as_record(value);
    }
    try {
        return as_record(globalThis.JSON.parse(value));
    } except Exception {
        return NULL;
    }
}

"""The first value that is neither undefined nor null: a chain of `??`."""
def:priv first(*values: any) -> any {
    for v in values {
        if not nil(v) {
            return v;
        }
    }
    return NULL;
}

def agentProviderErrorMessage(error: any) -> str {
    details = as_record(error);
    cause = as_record(field(details, "cause"));
    body = parse_response_body(
        first(field(details, "responseBody"), field(cause, "responseBody"), field(details, "data"))
    );
    provider_error = as_record(field(body, "error"));
    status = first(
        field(details, "statusCode"), field(cause, "statusCode"), field(provider_error, "code")
    );
    code: any = NULL;
    if kind(status) == "Number" and status >= 400 and status < 600 {
        code = status;
    } elif kind(status) == "String" and HTTP_ERROR.test(status) {
        code = globalThis.Number(status);
    }
    message = first(
        readable_text(field(as_record(field(provider_error, "metadata")), "raw")),
        readable_text(field(provider_error, "message")),
        readable_text(field(body, "error")),
        readable_text(field(body, "message")),
        readable_text(field(details, "message")),
        readable_text(error),
    );
    if (not message or message == "Provider returned error") and code == 429 {
        return "The AI provider is temporarily rate-limited. Retry shortly or choose another model.";
    }
    if not message {
        return "The assistant could not finish this request";
    }
    return f"AI provider error {code}: {message}" if code else message;
}
