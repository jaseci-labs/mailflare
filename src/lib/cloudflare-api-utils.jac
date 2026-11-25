glob:priv MX_HINT: str = """ If the token has Email Sending permissions, check the domain for MX
records pointing at another mail service; Cloudflare refuses sending setup until they are
removed.""",
          TOKEN_HINT: str = """ Verify CF_TOKEN with `curl
https://api.cloudflare.com/client/v4/user/tokens/verify -H "Authorization: Bearer <token>"`. Use
the token secret value without `Bearer`, or use CF_API_KEY plus CF_EMAIL for a Global API Key.""";

def:priv trimmed(env: any, name: str) -> any {
    value = at(env, name);
    return value.trim() if value else value;
}

def getCloudflareAuth(env: any) -> any {
    (token, key) = (trimmed(env, "CF_TOKEN"), trimmed(env, "CF_API_KEY"));
    email = trimmed(env, "CF_EMAIL");
    if key and email {
        return {"kind": "global-key", "email": email, "key": key};
    }
    if token {
        return {"kind": "token", "token": token};
    }
    no_email = "CF_EMAIL is required when using CF_API_KEY";
    raise new(globalThis.Error, no_email if key else "CF_TOKEN or CF_API_KEY is not configured");
}

def getCloudflareAuthHeaders(auth: any) -> any {
    if auth["kind"] == "global-key" {
        return {"X-Auth-Email": auth["email"], "X-Auth-Key": auth["key"]};
    }
    return {"Authorization": "Bearer " + globalThis.String(auth["token"])};
}

def formatCloudflareError(path: any, status: any, statusText: any, errors: any) -> str {
    code = lambda (e: any) -> str { f"code {e['code']}: " if at(e, "code") else "" };
    message = "; ".join([code(e) + globalThis.String(e["message"]) for e in errors]);
    message = message or statusText or "Cloudflare API request failed";
    return f"Cloudflare API {status} on {path}: {message}";
}

def getCloudflareAuthHint(errors: any, path: any = None) -> str {
    # Cloudflare answers a sending-subdomain create with 401/2036 when the hostname has another
    # service's MX records, so a valid token is not the likely cause.
    if "/email/sending/" in either(path, "") and any([e["code"] == 2036 for e in errors]) {
        return MX_HINT.replace("\n", " ");
    }
    auth = [e["code"] in [10000, 9109] or rx("auth|token", "i").test(e["message"]) for e in errors];
    return TOKEN_HINT.replace("\n", " ") if any(auth) else "";
}

def getEmailWorkerName(env: any = None) -> str {
    return trimmed(env, "CF_EMAIL_WORKER_NAME") or "mailflare";
}
