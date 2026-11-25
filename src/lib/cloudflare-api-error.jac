obj CloudflareApiError(globalThis.Error) {
    def init(message: str, status: any, path: any, errors: any) {
        super.init(message);
        (self.status, self.path) = (status, path);
        (self.errors, self.name) = (errors, "CloudflareApiError");
    }
}

def isCloudflareApiErrorCode(error: any, code: any) -> bool {
    return isinstance(error, CloudflareApiError) and any([e["code"] is code for e in error.errors]);
}

"""The zone left the account or the token cannot reach it (404, 403): nothing in it is usable."""
def isCloudflareZoneUnavailable(error: any) -> bool {
    named = isinstance(error, globalThis.Error) and error.name == "CloudflareApiError";
    return named and at(error, "status") in [404, 403];
}
