obj JmapError(globalThis.Error) {
    has `type: str,
        extra: any;

    def init(`type: str, description: any = None, extra: any = None) {
        super.init(either(description, `type));
        (self.type, self.extra) = (`type, globalThis.Object() if extra is None else extra);
    }

    def toMethodError -> any {
        said: dict[str, any] = {} if self.message == self.type else {"description": self.message};
        return merged({"type": self.type}, said, self.extra);
    }
}

def invalidArguments(description: str) -> JmapError {
    return JmapError("invalidArguments", description);
}

# RFC 8620 §5.5: a filter the server cannot apply is an error, never a silent match-all.
def unsupportedFilter(description: str) -> JmapError {
    return JmapError("unsupportedFilter", description);
}

def corsHeaders -> any {
    a = {"Origin": "*", "Methods": "GET, POST, OPTIONS", "Headers": "Authorization, Content-Type"};
    h = {f"Access-Control-Allow-{k}": v for (k, v) in a.items()};
    return record({**h, "Access-Control-Max-Age": "86400"});
}

# RFC 7807 problem document for request-level failures.
def problemResponse(kind: str, status: any, detail: str, extra: any = None) -> any {
    t = f"urn:ietf:params:jmap:error:{kind}";
    body = globalThis.JSON.stringify(
        merged({"type": t, "status": status, "detail": detail}, extra or {})
    );
    headers = merged({"Content-Type": "application/problem+json"}, corsHeaders());
    return new(globalThis.Response, body, record({"status": status, "headers": headers}));
}
