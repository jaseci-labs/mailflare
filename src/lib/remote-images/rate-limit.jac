glob:priv WINDOW_MS: int = 60000,
          MAX_REQUESTS: int = 300,
          MAX_TRACKED: int = 5000,
          windows: any = new(globalThis.Map);

# Fixed-window limit per user on proxied images, so thousands of unique image URLs cannot turn
# the proxy into a request amplifier; per-isolate/process state is enough for one noisy client.
def allowRemoteImageRequest(userId: str, now: any = None) -> bool {
    now = globalThis.Date.now() if now is None else now;
    current = windows.get(userId);
    if current and not (now - current.start >= WINDOW_MS) {
        current.count += 1;
        return current.count <= MAX_REQUESTS;
    }
    if windows.size >= MAX_TRACKED {
        [windows.delete(k) for (k, e) in list(windows.entries()) if now - e.start >= WINDOW_MS];
    }
    if windows.size >= MAX_TRACKED {
        windows.clear();
    }
    windows.set(userId, record({"start": now, "count": 1}));
    return True;
}
