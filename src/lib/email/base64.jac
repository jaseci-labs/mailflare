glob:priv SHAPE: any = rx(r"^[A-Za-z0-9+/]*(={0,2})$"),
          SPACE: any = rx(r"\s", "g");

"""True when `value` (whitespace ignored) is standard base64 that `atob` decodes without throwing."""
def isValidBase64(value: str) -> bool {
    compact: any = rx_sub(value, SPACE, "");
    found = SHAPE.exec(compact);
    if not found {
        return False;
    }
    rest = compact.length % 4;
    return rest == 0 if found[1] else rest != 1;
}
