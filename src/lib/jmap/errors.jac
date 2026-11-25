obj JmapError(globalThis.Error) {
    has `type: str,
        extra: any;

    def init(`type: str, description: any = None, extra: any = None) {
        super.init(either(description, `type));
        self.type = `type;
        self.extra = globalThis.Object() if extra is None else extra;
    }

    def toMethodError -> any {
        described: dict[str, any] = {}
            if self.message == self.type
            else {"description": self.message};
        return merged({"type": self.type}, described, self.extra);
    }
}

def invalidArguments(description: str) -> JmapError {
    return JmapError("invalidArguments", description);
}

"""RFC 8620 §5.5: a filter the server cannot apply is an error, never a silent match-all."""
def unsupportedFilter(description: str) -> JmapError {
    return JmapError("unsupportedFilter", description);
}

def corsHeaders -> any {
    return record({
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
        "Access-Control-Max-Age": "86400",
    });
}

"""RFC 7807 problem document for request-level failures."""
def problemResponse(kind: str, status: int, detail: str, extra: any = None) -> any {
    body = merged(
        {"type": f"urn:ietf:params:jmap:error:{kind}", "status": status, "detail": detail},
        extra or {},
    );
    return new(
        globalThis.Response,
        globalThis.JSON.stringify(body),
        record({
            "status": status,
            "headers": merged({"Content-Type": "application/problem+json"}, corsHeaders()),
        }),
    );
}
