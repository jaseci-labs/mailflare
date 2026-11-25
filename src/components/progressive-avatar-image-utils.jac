glob:priv KEY: str = "mailflare:avatars-loaded",
          loaded_full: any = NULL;

def getAvatarPreviewUrl(src: any) -> str {
    url = new(globalThis.URL, src, "http://localhost");
    url.searchParams.set("variant", "preview");
    return url.pathname + url.search;
}

def:priv read_loaded -> any {
    if not nil(loaded_full) {
        return loaded_full;
    }
    (loaded_full, now) = ({}, globalThis.Date.now());
    try {
        for e in globalThis.JSON.parse(globalThis.window.localStorage.getItem(KEY) or "[]") {
            if isinstance(e[0], str) and e[1] > now {
                loaded_full[e[0]] = e[1];
            }
        }
    } except Exception {}  # Storage may be unavailable or unreadable: this page's memory still works.
    return loaded_full;
}

"""Whether the full-size avatar finished loading before and should still be in the browser cache."""
def wasAvatarLoaded(src: any) -> bool {
    expires = read_loaded().get(src) if at(globalThis, "window") else None;
    return expires is not None and expires > globalThis.Date.now();
}

def rememberAvatarLoaded(src: any) {
    if at(globalThis, "window") {
        loaded = read_loaded();
        # The Cache-Control the avatar route sends: versioned URLs are immutable, others live 5 minutes.
        versioned = new(globalThis.URL, src, "http://localhost").searchParams.has("v");
        ttl = (30 * 24 * 60 if versioned else 5) * 60 * 1000;
        loaded.pop(src, None);
        loaded[src] = globalThis.Date.now() + ttl;
        while len(loaded) > 200 {
            del loaded[list(loaded)[0]];
        }
        data = globalThis.JSON.stringify([[k, v] for (k, v) in loaded.items()]);
        try {
            globalThis.window.localStorage.setItem(KEY, data);
        } except Exception {}  # Remembering across reloads is optional.
    }
}
