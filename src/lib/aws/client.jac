glob:priv DENIED: any = rx(
    r"AccessDenied|UnauthorizedOperation|AuthorizationError|NotAuthorized|Forbidden", "i"
);

obj AwsError(globalThis.Error) {
    def init(message: any, status: any, code: any) {
        super.init(message);
        (self.status, self.code) = (status, code);
        # A getter in TypeScript: not an own enumerable key (`has` drops it on a JavaScript base).
        denied = lambda -> bool { DENIED.test(self.code) or self.status == 403 };
        globalThis.Object.defineProperty(self, "accessDenied", record({"get": denied}));
    }
}

async def:priv parse_error(response: any) -> any {
    text = await response.text().catch(lambda (error: any) -> any { "" });
    kind = response.headers.get("x-amzn-errortype");
    (code, message, status) = ("" if nil(kind) else kind.split(":")[0], "", response.status);
    try {
        json = globalThis.JSON.parse(text);
        if json is NULL {
            raise new(globalThis.TypeError, "null");
        }
        named = at(json, "__type");
        code = code or ("" if nil(named) else named.split("#")[-1]);
        message = either(at(json, "message"), at(json, "Message", ""));
    } except Exception {
        code = code or either(xmlTag(text, "Code"), "");
        message = either(xmlTag(text, "Message"), "");
    }
    return AwsError(message or f"AWS request failed ({status})", status, code or f"HTTP{status}");
}

"""`request` is { config, service, host?, method?, path?, query?, body?, headers?, region? }."""
async def awsRequest(request: any) -> any {
    (config, service) = (request["config"], request["service"]);
    region = at(request, "region", config["region"]);
    host = at(request, "host", f"{service}.{region}.amazonaws.com");
    url = new(globalThis.URL, f"https://{host}{at(request, 'path', '/')}");
    for (name, value) in entries(at(request, "query", {})) {
        url.searchParams.set(name, value);
    }
    (body, method) = (at(request, "body", ""), at(request, "method", "GET"));
    signed = {"method": method, "url": url, "headers": at(request, "headers", {}), "body": body};
    signed = {**signed, "region": region, "service": service, "credentials": config};
    hs = await signAwsRequest(signed);
    init = {"method": method, "headers": hs, "body": None if method in ("GET", "HEAD") else body};
    response = await globalThis.fetch(url, record(init));
    if not response.ok {
        raise await parse_error(response);
    }
    return response;
}

"""AWS JSON REST (SES v2): `request.json`, when given, is the body."""
async def awsJson(request: any) -> any {
    payload = request.get("json") if isinstance(request, dict) else getattr(request, "json", None);
    body = at(request, "body") if payload is None else globalThis.JSON.stringify(payload);
    hs = merged({"Content-Type": "application/json"}, at(request, "headers", {}));
    text = await (await awsRequest(merged(request, {"body": body, "headers": hs}))).text();
    return globalThis.JSON.parse(text or "{}");
}

"""AWS Query protocol (STS, SNS, SES v1): form-encoded POST, XML back."""
async def awsQuery(
    config: any, service: str, version: str, action: str, params: any = None, options: any = None
) -> str {
    form = merged({"Action": action, "Version": version}, either(params, {}));
    host = at(options, "host", f"{service}.{config['region']}.amazonaws.com");
    hs = {"Content-Type": "application/x-www-form-urlencoded; charset=utf-8"};
    req = {"config": config, "service": at(options, "signingService", service), "host": host};
    body = new(globalThis.URLSearchParams, form).toString();
    response = await awsRequest({**req, "method": "POST", "body": body, "headers": hs});
    return await response.text();
}

"""`await call`, or undefined when it fails with an AwsError of a `code` (a regex) or `status`."""
async def awsSpare(call: any, code: str = "", status: int = 0) -> any {
    try {
        return await call;
    } except Exception as caught {
        # `except` wraps a JavaScript error; the error itself, to rethrow as it was, is `js`.
        c: any = caught;
        e: any = getattr(c, "js", c);
        if isinstance(e, AwsError) and (e.status == status or rx(f"^(?:{code})$").test(e.code)) {
            return None;
        }
        raise e;
    }
}
