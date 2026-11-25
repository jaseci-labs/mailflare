"""An API failure that keeps its stable code for translation at the call site."""
obj ClientRequestError(globalThis.Error) {
    def init(message: any, code: any = None) {
        super.init(message);
        (self.code, self.name) = (code, "ClientRequestError");
    }
}

def requestError(data: any, fallback: str) -> ClientRequestError {
    code = data["code"] if isinstance(data["code"], str) else None;
    return ClientRequestError(data["error"] if isinstance(data["error"], str) else fallback, code);
}
