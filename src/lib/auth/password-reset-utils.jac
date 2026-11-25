glob:priv R: str = "auth.resetMail.";

def escapeHtml(value: str) -> str {
    v = value.replace("&", "&amp;").replace("<", "&lt;");
    return v.replace(">", "&gt;").replace('"', "&quot;");
}

def buildPasswordResetEmail(t: any, m: any) -> any {
    (email, app, link, e) = (m["email"], m["appName"], m["link"], escapeHtml);
    (ignore, steps) = (t(R + "ignore"), t(R + "instructions", record({"minutes": m["minutes"]})));
    intro = t(R + "intro", record({"email": f"<b>{e(email)}</b>", "appName": e(app)}));
    text = [t(R + "intro", record({"email": email, "appName": app})), "", steps, link, "", ignore];
    return {
        "subject": t(R + "subject", record({"appName": app})),
        "text": "\n".join(text),
        "html": f'<p>{intro}</p><p>{e(steps)}</p><p><a href="{e(link)}">{e(link)}</a></p><p>{e(ignore)}</p>',
    };
}

"""The origin a reset link may point at. It carries a live credential, so never from a header the
requester controls: APP_URL wins; else Workers know their public origin, but the self-hosted server
builds `request.url` from the Host header, so there is no trusted origin: send no mail."""
def trustedResetOrigin(env: any, requestUrl: any) -> any {
    c: any = at(env, "APP_URL");
    if c and c.trim() {
        try {
            return new(globalThis.URL, c.trim()).origin;
        } except Exception {
            return NULL;
        }
    }
    return NULL if env["MAILFLARE_RUNTIME"] == "node" else new(globalThis.URL, requestUrl).origin;
}
