async def:priv call(path: str, opts: any, failure: str) -> any {
    response = await globalThis.fetch("/api/admin/" + path, record(opts));
    data = await response.json();
    if not response.ok {
        raise new(globalThis.Error, either(data["error"], failure));
    }
    return data;
}

async def getApplicationUpdateStatus -> any {
    return await call("update", {"cache": "no-store"}, "Could not check for updates");
}

async def triggerApplicationUpdate -> any {
    return await call("update", {"method": "POST"}, "Could not start the update");
}

async def getMigrationStatus -> any {
    return await call("migrations", {"cache": "no-store"}, "Could not check database migrations");
}

async def applyDatabaseMigrations -> any {
    return await call("migrations", {"method": "POST"}, "Could not apply database migrations");
}

async def saveUpdateSettings(values: any) -> any {
    headers = {"Content-Type": "application/json"};
    opts = {"method": "PATCH", "headers": headers, "body": globalThis.JSON.stringify(values)};
    response = await globalThis.fetch("/api/admin/update", record(opts));
    if not response.ok {
        data = record({});
        try {
            data = await response.json();
        } except Exception {}
        raise new(globalThis.Error, either(data["error"], "Could not save the update settings"));
    }
}
