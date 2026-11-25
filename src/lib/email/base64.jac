# True when `value` (whitespace ignored) is standard base64 that `atob` decodes without throwing.
def isValidBase64(value: str) -> bool {
    compact: any = rx_sub(value, rx(r"\s", "g"), "");
    found = rx(r"^[A-Za-z0-9+/]*(={0,2})$").exec(compact);
    return bool(found) and (compact.length % 4 == 0 if found[1] else compact.length % 4 != 1);
}
