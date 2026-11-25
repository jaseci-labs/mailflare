glob DEFAULT_BRANDING: any = record({
    "appName": "Mailflare",
    "hasCustomIcon": False,
    "canCustomizeBranding": False,
});

async def fetchBranding -> any {
    response = await globalThis.fetch("/api/branding", record({"cache": "no-store"}));
    return (await response.json()) if response.ok else DEFAULT_BRANDING;
}
