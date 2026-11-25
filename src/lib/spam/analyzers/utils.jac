"""The value of the first header whose name lowercases to `name` (case-insensitive lookup)."""
def findHeader(headers: any, name: str) -> any {
    if nil(headers) {
        return None;
    }
    for key in globalThis.Object.keys(headers) {
        lowered: str = globalThis.String.prototype.toLowerCase.call(key);
        if lowered == name {
            return globalThis.Reflect.get(globalThis.Object(headers), key) if key else None;
        }
    }
    return None;
}
