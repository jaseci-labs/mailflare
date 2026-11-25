"""The distinct, trimmed model ids of a comma-separated setting, in order."""
def parseAgentModelIds(value: any) -> list[str] {
    models: list[str] = [];
    for part in value.split(",") {
        model: any = part;
        model = model.trim();
        if model and model not in models {
            models.append(model);
        }
    }
    return models;
}

def toggleAgentModelId(value: any, modelId: str, checked: bool) -> str {
    models = parseAgentModelIds(value);
    if not checked {
        return ", ".join([m for m in models if m != modelId]);
    }
    return ", ".join(models if modelId in models else [*models, modelId]);
}
