glob:priv KEY: str = "mailflare-sidebar-minimal";
glob sidebarBootstrapScript: str = """(() => {
	try {
		const minimalKey = "mailflare-sidebar-minimal";
		const widthKey = "mailflare-column-width:sidebar";
		let minimal = localStorage.getItem(minimalKey);
		let width = localStorage.getItem(widthKey);
		if (minimal === null) {
			const keys = Object.keys(localStorage).filter((key) => key.startsWith(minimalKey + ":"));
			if (keys.length === 1) minimal = localStorage.getItem(keys[0]);
		}
		if (width === null) {
			const keys = Object.keys(localStorage).filter((key) => key.startsWith(widthKey + ":"));
			if (keys.length === 1) width = localStorage.getItem(keys[0]);
		}
		if (minimal === "true") document.documentElement.style.setProperty("--persisted-sidebar-width", "72px");
		else if (width !== null && Number.isFinite(Number(width))) document.documentElement.style.setProperty("--persisted-sidebar-width", Math.max(200, Math.min(480, Number(width))) + "px");
	} catch {}
})();""";

def syncInitialSidebarWidth(width: any, minimal: any) {
    if at(globalThis, "document") {
        px = f"{72 if minimal else width}px";
        globalThis.document.documentElement.style.setProperty("--persisted-sidebar-width", px);
    }
}

def readInitialSidebarMinimal -> bool {
    if not at(globalThis, "window") {
        return False;
    }
    try {
        ls = globalThis.localStorage;
        keys = [k for k in globalThis.Object.keys(ls) if k.startswith(KEY + ":")];
        return either(ls.getItem(KEY), ls.getItem(keys[0]) if len(keys) == 1 else NULL) == "true";
    } except Exception {
        return False;
    }
}

def saveInitialSidebarMinimal(minimal: any) {
    try {
        globalThis.localStorage.setItem(KEY, globalThis.String(minimal));
    } except Exception {}  # Storage can be unavailable in private windows.
}
