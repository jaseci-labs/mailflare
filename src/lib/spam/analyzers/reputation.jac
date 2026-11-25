"""What a message's reputation is kept under: its sender, the sender's domain, and its fingerprint."""
def getReputationKeys(message: any, fingerprint: str) -> list[any] {
    email = getEmailAddress(at(message, "fromAddr", "")).lower();
    found = [("email", email), ("domain", getDomain(email)), ("fingerprint", fingerprint)];
    return [{"type": kind, "key": key} for (kind, key) in found if key or kind == "fingerprint"];
}
