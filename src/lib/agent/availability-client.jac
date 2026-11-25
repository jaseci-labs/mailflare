glob:priv STORAGE_KEY = "mailflare-assistant-enabled";

def readInitialAssistantAvailability -> any {
    if getattr(globalThis, "window", None) is None {
        return NULL;
    }
    try {
        stored = globalThis.localStorage.getItem(STORAGE_KEY);
        return NULL if stored is NULL else stored == "true";
    } except Exception {
        return NULL;
    }
}

def saveAssistantAvailability(enabled: any) {
    try {
        globalThis.localStorage.setItem(STORAGE_KEY, globalThis.String(enabled));
    } except Exception {
        # Storage is optional.
        return;
    }
}
