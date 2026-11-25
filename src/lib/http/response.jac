"""
Parse a response body as a JSON object, or `{}` when it is not JSON (for example an HTML 502 page
from a proxy). Callers then fall through to their own `res.ok` handling and fallback message.
"""
async def readResponseJson(res: any) -> any {
    try {
        data = await res.json();
    } except Exception {
        return globalThis.Object();
    }
    # an empty array is falsy in Jac and truthy in JavaScript
    is_object = globalThis.Object(data) is data and (bool(data) or globalThis.Array.isArray(data));
    return data if is_object else globalThis.Object();
}
