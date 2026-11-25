"""Commands whose title, subtitle, category or a keyword contains the query, ignoring case."""
def filterCommands(commands: any, query: any) -> any {
    q = query.trim().toLowerCase();
    def hit(v: any) -> bool {
        return not nil(v) and q in v.toLowerCase();
    }
    def matches(c: any) -> bool {
        words = [c["title"], at(c, "subtitle"), c["category"], *either(at(c, "keywords"), [])];
        return any([hit(w) for w in words]);
    }
    return [c for c in commands if matches(c)] if q else commands;
}

def groupCommandsByCategory(commands: any) -> any {
    groups: dict[any, list[any]] = {};
    for c in commands {
        groups.setdefault(c["category"], []).append(c);
    }
    return groups;
}
