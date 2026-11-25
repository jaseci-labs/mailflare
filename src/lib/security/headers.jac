# Dev tooling (HMR, source maps) evaluates strings; production never needs to.
glob:priv SCRIPT_EVAL: str = ""
    if globalThis.process.env.NODE_ENV == "production"
    else " 'unsafe-eval'";

glob:priv CSP: str = "; ".join([
    "default-src 'self'",
    f"script-src 'self' 'unsafe-inline'{SCRIPT_EVAL} https://challenges.cloudflare.com",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob: https:",
    "font-src 'self' data:",
    "connect-src 'self' ws: wss: https://challenges.cloudflare.com",
    # 'self' lets the Drive preview show PDFs and text files in an iframe.
    "frame-src 'self' https://challenges.cloudflare.com",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'self'",
    "upgrade-insecure-requests",
]);

glob:priv HEADERS: list[tuple[str, str]] = [
    ("X-Robots-Tag", "noindex, nofollow, noarchive, nosnippet, noimageindex"),
    ("Content-Security-Policy", CSP),
    ("Strict-Transport-Security", "max-age=31536000; includeSubDomains"),
    ("X-Content-Type-Options", "nosniff"),
    ("X-Frame-Options", "SAMEORIGIN"),
    # No window the app opens or that opens the app keeps a reference to it.
    ("Cross-Origin-Opener-Policy", "same-origin"),
    ("Referrer-Policy", "strict-origin-when-cross-origin"),
    ("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=(), usb=()"),
];

def getSecurityHeaders -> list[dict[str, str]] {
    return [{"key": key, "value": value} for (key, value) in HEADERS];
}
