def setAppBadgeCount(count: any) {
    (n, ignore) = (globalThis.navigator, lambda (e: any) -> any { None });
    if globalThis.Reflect.has(n, "setAppBadge") {  # rejected outside an installed app: cosmetic
        (n.setAppBadge(count) if count > 0 else n.clearAppBadge()).catch(ignore);
    }
}
