glob THEME_STORAGE_KEY: str = "mailflare-theme",
     THEME_CHANGED_EVENT: str = "mailflare:theme-changed";
type ThemePreference = any;

# Runs in <head> before paint so the first frame has the right theme; keep in sync with applyTheme.
glob themeBootstrapScript: str = """(() => {
	try {
		const saved = localStorage.getItem("mailflare-theme");
		const preference = saved === "light" || saved === "dark" ? saved : "system";
		const dark = preference === "dark" || (preference === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
		document.documentElement.classList.toggle("dark", dark);
		document.documentElement.classList.toggle("light", !dark);
	} catch {}
})();""";

def isThemePreference(value: any) -> bool {
    return value in ["light", "dark", "system"];
}

def readThemePreference -> any {
    try {
        s = at(globalThis, "window") and globalThis.localStorage.getItem(THEME_STORAGE_KEY);
    } except Exception {}
    return s if isThemePreference(s) else "system";
}

def resolveTheme(preference: any) -> any {
    w = at(globalThis, "window");
    if preference != "system" {
        return preference;
    }
    return "dark" if w and w.matchMedia("(prefers-color-scheme: dark)").matches else "light";
}

def applyTheme(preference: any) {
    if at(globalThis, "document") {
        dark = resolveTheme(preference) == "dark";
        globalThis.document.documentElement.classList.toggle("dark", dark);
        globalThis.document.documentElement.classList.toggle("light", not dark);
    }
}

def saveThemePreference(preference: any) {
    try {
        globalThis.localStorage.removeItem(THEME_STORAGE_KEY)
            if preference == "system"
            else globalThis.localStorage.setItem(THEME_STORAGE_KEY, preference);
    } except Exception {}  # Private windows may lack storage; the theme still applies to this page.
    applyTheme(preference);
    if at(globalThis, "window") {
        detail = record({"detail": preference});
        globalThis.window.dispatchEvent(new(globalThis.CustomEvent, THEME_CHANGED_EVENT, detail));
    }
}
