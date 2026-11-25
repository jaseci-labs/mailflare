glob:priv DENIED: any = rx(
    r"AccessDenied|UnauthorizedOperation|AuthorizationError|NotAuthorized|Forbidden", "i"
);

obj AwsError(globalThis.Error) {
    def init(message: any, status: any, code: any) {
        super.init(message);
        self.status = status;
        self.code = code;
        # A getter in TypeScript: read each time, and not one of the error's own enumerable keys.
        # (A `has ... { getter }` property is dropped on a class that extends a JavaScript one.)
        globalThis.Object.defineProperty(
            self,
            "accessDenied",
            record({"get": lambda -> bool { DENIED.test(self.code) or self.status == 403 }}),
        );
    }
}

"""`o.k` as it is, null included, of a Jac dict or a JavaScript object."""
def:priv raw(o: any, k: str) -> any {
    return o.get(k) if isinstance(o, dict) else getattr(o, k, None);
}

async def:priv parse_error(response: any) -> any {
    text = await response.text().catch(lambda (error: any) -> any { "" });
    kind = response.headers.get("x-amzn-errortype");
    code: any = "" if nil(kind) else kind.split(":")[0];
    message: any = "";
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
    status = response.status;
    return AwsError(message or f"AWS request failed ({status})", status, code or f"HTTP{status}");
}

"""
`request` is { config, service, host?, method?, path?, query?, body?, headers?, region? }: the host
defaults to `<service>.<region>.amazonaws.com`, and the signing region to the config's.
"""
async def awsRequest(request: any) -> any {
    (config, service) = (request["config"], request["service"]);
    region = at(request, "region", config["region"]);
    host = at(request, "host", f"{service}.{region}.amazonaws.com");
    url = new(globalThis.URL, f"https://{host}{at(request, 'path', '/')}");
    for (name, value) in entries(at(request, "query", {})) {
        url.searchParams.set(name, value);
    }
    body = at(request, "body", "");
    method = at(request, "method", "GET");
    headers = await signAwsRequest({
        "method": method,
        "url": url,
        "headers": at(request, "headers", {}),
        "body": body,
        "region": region,
        "service": service,
        "credentials": config,
    });
    response = await globalThis.fetch(
        url,
        record({
            "method": method,
            "headers": headers,
            "body": None if method in ("GET", "HEAD") else body,
        }),
    );
    if not response.ok {
        raise await parse_error(response);
    }
    return response;
}

"""AWS JSON REST (SES v2): `request.json`, when given, is the body."""
async def awsJson(request: any) -> any {
    payload = raw(request, "json");
    response = await awsRequest(
        merged(
            request,
            {
                "body": at(request, "body")
                    if payload is None
                    else globalThis.JSON.stringify(payload),
                "headers": merged({"Content-Type": "application/json"}, at(request, "headers", {})),
            },
        ),
    );
    text = await response.text();
    return globalThis.JSON.parse(text or "{}");
}

"""AWS Query protocol (STS, SNS, SES v1): form-encoded POST, XML back."""
async def awsQuery(
    config: any, service: str, version: str, action: str, params: any = None, options: any = None
) -> str {
    options = {} if options is None else options;
    body = new(
        globalThis.URLSearchParams,
        merged({"Action": action, "Version": version}, either(params, {})),
    ).toString();
    response = await awsRequest({
        "config": config,
        "service": at(options, "signingService", service),
        "host": at(options, "host", f"{service}.{config['region']}.amazonaws.com"),
        "method": "POST",
        "body": body,
        "headers": {"Content-Type": "application/x-www-form-urlencoded; charset=utf-8"},
    });
    return await response.text();
}
