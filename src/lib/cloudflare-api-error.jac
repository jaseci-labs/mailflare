obj CloudflareApiError(globalThis.Error) {
    def init(message: str, status: any, path: any, errors: any) {
        super.init(message);
        self.status = status;
        self.path = path;
        self.errors = errors;
        self.name = "CloudflareApiError";
    }
}

def isCloudflareApiErrorCode(error: any, code: any) -> bool {
    return isinstance(error, CloudflareApiError)
        and bool([item for item in error.errors if item["code"] is code]);
}

"""The zone is gone from the account or the token cannot reach it (404, 403): nothing in it can be read or changed from here."""
def isCloudflareZoneUnavailable(error: any) -> bool {
    return isinstance(error, globalThis.Error)
        and error.name == "CloudflareApiError"
        and at(error, "status") in [404, 403];
}
