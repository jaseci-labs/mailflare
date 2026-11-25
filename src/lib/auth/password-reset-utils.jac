def escapeHtml(value: str) -> str {
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace(
        '"', "&quot;"
    );
}

def buildPasswordResetEmail(t: any, mail: any) -> dict[str, str] {
    (email, appName, link, minutes) = (
        mail["email"],
        mail["appName"],
        mail["link"],
        mail["minutes"],
    );
    ignore = t("auth.resetMail.ignore");
    instructions = t("auth.resetMail.instructions", record({"minutes": minutes}));
    intro = t(
        "auth.resetMail.intro",
        record({"email": f"<b>{escapeHtml(email)}</b>", "appName": escapeHtml(appName)}),
    );
    return {
        "subject": t("auth.resetMail.subject", record({"appName": appName})),
        "text": "\n".join([
            t("auth.resetMail.intro", record({"email": email, "appName": appName})),
            "",
            instructions,
            link,
            "",
            ignore,
        ]),
        "html": f'<p>{intro}</p><p>{escapeHtml(instructions)}</p><p><a href="{escapeHtml(link)}">{escapeHtml(link)}</a></p><p>{escapeHtml(ignore)}</p>',
    };
}

"""The origin a reset link may point at. The link carries a live credential, so it must never come from
a header the requester controls. APP_URL wins. Without it, Workers still know their public origin
(the edge rejects other Host values), but the self-hosted server builds `request.url` from the Host
header, so there is no trusted origin and the caller must not send the mail."""
def trustedResetOrigin(env: any, requestUrl: any) -> any {
    appUrl: any = at(env, "APP_URL");
    configured = appUrl.trim() if appUrl else None;
    if configured {
        try {
            return new(globalThis.URL, configured).origin;
        } except Exception {
            return NULL;
        }
    }
    if at(env, "MAILFLARE_RUNTIME") == "node" {
        return NULL;
    }
    return new(globalThis.URL, requestUrl).origin;
}
