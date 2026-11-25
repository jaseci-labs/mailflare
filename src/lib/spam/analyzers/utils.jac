def findHeader(headers: any, name: str) -> any {
    return first([v for (k, v) in entries(either(headers, {})) if k and k.toLowerCase() == name]);
}
