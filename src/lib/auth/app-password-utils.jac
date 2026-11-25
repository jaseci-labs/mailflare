"""An app password, or one of the older JMAP-only keys that did the same job before app passwords."""
def isListedAsAppPassword(key: any) -> bool {
    scopes = parseScopes(key["scopes"]);
    kind: any = key["kind"];
    return kind == "app" or (kind == "legacy" and len(scopes) == 1 and scopes[0] == "jmap");
}
