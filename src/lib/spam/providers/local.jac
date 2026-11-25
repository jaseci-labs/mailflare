"""The intelligence provider that looks nothing up."""
obj LocalSpamIntelligenceProvider {
    def check -> any {
        return globalThis.Promise.resolve([]);
    }
}
