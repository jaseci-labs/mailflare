"""An app password, or one of the older JMAP-only keys that did the same job before app passwords existed."""
def isListedAsAppPassword(key: any) -> bool {
    if key["kind"] == "app" {
        return True;
    }
    scopes = parseScopes(key["scopes"]);
    return key["kind"] == "legacy" and len(scopes) == 1 and scopes[0] == "jmap";
}
