# A response body as a JSON object, or `{}` when it is not JSON (e.g. a proxy's HTML 502 page):
# callers then fall through to their own `res.ok` handling and fallback message.
async def readResponseJson(res: any) -> any {
    try {
        data = await res.json();
    } except Exception {
        data = NULL;
    }
    return data if is_object(data) else globalThis.Object();
}
