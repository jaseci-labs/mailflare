def readInitialAssistantPanelState -> any {
    try {
        if getattr(globalThis, "window", None) is not None {
            keys = [f"mailflare-dashboard:assistant-{k}" for k in ["open", "full-size"]];
            (isOpen, full) = [globalThis.localStorage.getItem(k) == "true" for k in keys];
            return {"open": isOpen, "fullSize": full};
        }
    } except Exception {}
    return {"open": False, "fullSize": False};
}

# Storage is optional: a browser that refuses it keeps the defaults.
def saveAssistantPanelState(isOpen: bool, fullSize: bool, userPrefix: any) {
    try {
        store = globalThis.localStorage;
        for stem in ["mailflare-dashboard"] + ([userPrefix] if userPrefix else []) {
            store.setItem(f"{stem}:assistant-open", globalThis.String(isOpen));
            store.setItem(f"{stem}:assistant-full-size", globalThis.String(fullSize));
        }
    } except Exception {}
}
