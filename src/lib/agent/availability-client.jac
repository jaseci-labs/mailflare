glob:priv K: str = "mailflare-assistant-enabled";

def readInitialAssistantAvailability -> any {
    try {
        s = at(globalThis, "window") and globalThis.localStorage.getItem(K);
    } except Exception {}
    return NULL if nil(s) else s == "true";
}

def saveAssistantAvailability(enabled: any) {
    try {
        globalThis.localStorage.setItem(K, globalThis.String(enabled));
    } except Exception {}
}
