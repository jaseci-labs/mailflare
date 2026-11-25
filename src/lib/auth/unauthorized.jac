"""Thrown by `requireUser` when nobody is signed in. The `digest` is the one Next.js and vinext use for
`unauthorized()`, so a route handler that lets it escape answers 401 instead of a generic 500."""
obj UnauthorizedError(globalThis.Error) {
    has digest: str = "NEXT_HTTP_ERROR_FALLBACK;401";

    def init {
        super.init("Unauthorized");
        self.name = "UnauthorizedError";
    }
}
