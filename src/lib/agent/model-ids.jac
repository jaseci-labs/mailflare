def parseAgentModelIds(value: any) -> any {
    return [*new(globalThis.Set, [m for m in [p.trim() for p in value.split(",")] if m])];
}

def toggleAgentModelId(value: any, id: any, checked: any) -> any {
    ms: any = parseAgentModelIds(value);
    return ", ".join((ms if id in ms else [*ms, id]) if checked else [m for m in ms if m != id]);
}
