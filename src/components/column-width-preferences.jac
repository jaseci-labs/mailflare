def:priv clamp(stored: any, fallback: any, lo: any, hi: any) -> any {
    (M, w) = (globalThis.Math, globalThis.Number(stored));
    ok = stored is not NULL and globalThis.Number.isFinite(w);
    return M.max(lo, M.min(hi, w)) if ok else fallback;
}

def readInitialColumnWidth(column: any, fallback: any, min: any, max: any) -> any {
    if not at(globalThis, "window") {
        return fallback;
    }
    try {
        (ls, key) = (globalThis.localStorage, f"mailflare-column-width:{column}");
        # No device-wide width yet: use the one user-scoped width if there is exactly one.
        keys = [k for k in globalThis.Object.keys(ls) if k.startswith(key + ":")];
        stored = either(ls.getItem(key), ls.getItem(keys[0]) if len(keys) == 1 else NULL);
        return clamp(stored, fallback, min, max);
    } except Exception {
        return fallback;
    }
}

def readColumnWidth(userId: any, column: any, fallback: any, min: any, max: any) -> any {
    try {
        stored = globalThis.localStorage.getItem(f"mailflare-column-width:{column}:{userId}");
        return clamp(stored, fallback, min, max);
    } except Exception {
        return fallback;
    }
}

def saveColumnWidth(userId: any, column: any, width: any) {
    (key, value) = (f"mailflare-column-width:{column}", globalThis.String(width));
    try {
        globalThis.localStorage.setItem(key, value);
        if userId {
            globalThis.localStorage.setItem(f"{key}:{userId}", value);
        }
    } except Exception {}  # Storage can be unavailable; resizing still works for this session.
}
