import from "@simplewebauthn/browser" { WebAuthnError }

"""The browser prompt was dismissed, cancelled, or timed out."""
def isPasskeyCancellation(error: any) -> bool {
    web = isinstance(error, WebAuthnError);
    named = (web or isinstance(error, globalThis.DOMException))
        and error.name in ["NotAllowedError", "AbortError"];
    return named or (web and error.code == "ERROR_CEREMONY_ABORTED");
}

"""The browser or platform cannot perform this ceremony at all."""
def isPasskeyUnsupported(error: any) -> bool {
    return isinstance(error, WebAuthnError) and error.name == "NotSupportedError";
}
