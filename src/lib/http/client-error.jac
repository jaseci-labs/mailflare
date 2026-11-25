"""An API failure that keeps its stable code for translation at the call site."""
obj ClientRequestError(globalThis.Error) {
    def init(message: any, code: any = None) {
        super.init(message);
        self.code = code;
        self.name = "ClientRequestError";
    }
}

def requestError(data: any, fallback: str) -> ClientRequestError {
    (error, code) = (data["error"], data["code"]);
    return ClientRequestError(
        error if isinstance(error, str) else fallback, code if isinstance(code, str) else None
    );
}
