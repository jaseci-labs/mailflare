import from "drizzle-orm" { eq }

glob:priv TRAILING_SLASH: any = rx(r"/$");

def resolveAgentBaseUrl(preset: any, customUrl: any) -> str {
    if preset != "custom" {
        return PROVIDER_BASE_URLS[preset];
    }
    url = new(globalThis.URL, customUrl.trim());
    if url.protocol != "https:" or url.username or url.password or url.search or url.hash {
        raise new(
            globalThis.Error,
            "Custom provider URL must be an HTTPS base URL without credentials or query parameters",
        );
    }
    return rx_sub(url.toString(), TRAILING_SLASH, "");
}

"""The chosen columns of the one settings row, or None before it exists."""
async def:priv saved_settings(env: any, columns: dict[str, any]) -> any {
    rows = await getDb(env).select(record(columns)).from(appSettings).where(
        eq(appSettings.id, AGENT_SETTINGS_ID)
    ).limit(1);
    return rows[0] if len(rows) else None;
}

async def getAgentEnabled(env: any) -> bool {
    saved = await saved_settings(env, {"enabled": appSettings.agentEnabled});
    return either(saved["enabled"], True) if saved else True;
}

"""The saved provider when there is one, else what the environment offers, else Workers AI's default model."""
async def getAgentProviderConfig(env: any) -> dict[str, any] {
    saved = await saved_settings(
        env,
        {
            "provider": appSettings.agentProvider,
            "preset": appSettings.agentPreset,
            "baseUrl": appSettings.agentBaseUrl,
            "apiKey": appSettings.agentApiKey,
            "model": appSettings.agentModel,
            "rates": appSettings.agentModelRates,
        },
    );
    rates = parseAgentModelRates(either(saved["rates"], NULL) if saved else NULL);
    provider = saved["provider"] if saved else None;
    cloudflare = {
        "provider": "cloudflare",
        "preset": "openai",
        "baseUrl": "",
        "apiKey": "",
        "rates": rates,
    };
    (ai_model, ai_url, ai_key) = (
        at(env, "AI_MODEL"),
        at(env, "AI_BASE_URL"),
        at(env, "AI_API_KEY"),
    );
    if provider == "cloudflare" {
        models = parseAgentModelIds(saved["model"] or ai_model or DEFAULT_CLOUDFLARE_MODEL);
        model = models[0] if models else DEFAULT_CLOUDFLARE_MODEL;
        return {**cloudflare, "model": model, "models": models, "source": "saved"};
    }
    if provider == "compatible" {
        preset = saved["preset"] or "custom";
        base_url = resolveAgentBaseUrl(preset, saved["baseUrl"] or "");
        models = parseAgentModelIds(saved["model"] or "");
        return {
            "provider": "compatible",
            "preset": preset,
            "baseUrl": base_url,
            "apiKey": saved["apiKey"] or (ai_key if ai_url == base_url else "") or "",
            "model": models[0] if models else "",
            "models": models,
            "rates": rates,
            "source": "saved",
        };
    }
    if at(env, "AI") {
        model = ai_model or DEFAULT_CLOUDFLARE_MODEL;
        return {**cloudflare, "model": model, "models": [model], "source": "environment"};
    }
    if ai_url and ai_key {
        model = ai_model or "gpt-4o-mini";
        return {
            "provider": "compatible",
            "preset": "custom",
            "baseUrl": ai_url,
            "apiKey": ai_key,
            "model": model,
            "models": [model],
            "rates": rates,
            "source": "environment",
        };
    }
    return {
        **cloudflare,
        "model": DEFAULT_CLOUDFLARE_MODEL,
        "models": [DEFAULT_CLOUDFLARE_MODEL],
        "source": "default",
    };
}

"""The provider config without its key: only whether one is set, and whether the assistant can run."""
async def getAgentProviderPublicConfig(env: any) -> dict[str, any] {
    config = await getAgentProviderConfig(env);
    key = config.pop("apiKey");
    has_models = len(config["models"]) > 0;
    configured = bool(at(env, "AI")) and has_models
        if config["provider"] == "cloudflare"
        else bool(key) and bool(config["baseUrl"]) and has_models;
    return {**config, "hasApiKey": bool(key), "configured": configured};
}
