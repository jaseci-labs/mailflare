"""The value of the first header whose name is `name` (given lower-cased), whatever its case."""
def findHeader(headers: any, name: str) -> any {
    for (key, value) in entries(either(headers, {})) {
        if key.toLowerCase() == name {
            return value if key else None;
        }
    }
    return None;
}
