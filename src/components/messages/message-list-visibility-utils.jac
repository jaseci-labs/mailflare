glob:priv KEY: str = "mailflare-message-list-visible";

def readInitialMessageListVisible -> bool {
    try {
        return not at(globalThis, "window") or globalThis.localStorage.getItem(KEY) != "false";
    } except Exception {}
    return True;
}

def saveMessageListVisible(visible: any) {
    try {
        globalThis.localStorage.setItem(KEY, globalThis.String(visible));
    } except Exception {}  # Storage is optional.
}
