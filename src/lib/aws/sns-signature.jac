glob SNS_MAX_AGE_MS: int = 24 * 60 * 60 * 1000;

glob:priv CERTS: any = new(globalThis.Map);

"""The fields SNS signs, in the order it signs them (Amazon SNS "Verifying the signatures" docs)."""
def:priv string_to_sign(env: any) -> str | None {
    kind = getattr(env, "Type", None);
    confirm = kind in ["SubscriptionConfirmation", "UnsubscribeConfirmation"];
    keys = "SubscribeURL Timestamp Token" if confirm else "Subject Timestamp";
    pairs = [(k, getattr(env, k, None)) for k in f"Message MessageId {keys} TopicArn Type".split()];
    missing = any([v is None and k != "Subject" for (k, v) in pairs]);
    if kind != "Notification" and not confirm or missing {
        return None;
    }
    return "".join([k + "\n" + globalThis.String(v) + "\n" for (k, v) in pairs if v is not None]);
}

def isValidSigningCertUrl(value: any = None) -> bool {
    try {
        url = new(globalThis.URL, value);
        host = rx(r"^sns\.[a-z0-9-]+\.amazonaws\.com(?:\.cn)?$").test(url.hostname);
        pem = url.pathname.endsWith(".pem");
        return bool(value) and url.protocol == "https:" and not url.port and host and pem;
    } except Exception {
        return False;
    }
}

def:priv binary(text: any) -> any {
    return new(globalThis.Uint8Array, [char.charCodeAt(0) for char in text]);
}

"""Reads one DER element at `i`: its tag, header length and content length."""
def:priv read_der(b: any, i: any) -> tuple[any, any, any] {
    # `b[i]` as JavaScript reads it: undefined past the end.
    (tag, first) = (globalThis.Reflect.get(b, i), globalThis.Reflect.get(b, i + 1));
    if first is None or first < 0x80 {
        return (tag, 2, either(first, 0));
    }
    length: any = 0;
    for k in range(first & 0x7f) {
        length = length * 256 + either(globalThis.Reflect.get(b, i + 2 + k), globalThis.NaN);
    }
    return (tag, 2 + (first & 0x7f), length);
}

"""Pulls the SubjectPublicKeyInfo out of an X.509 certificate: Web Crypto cannot import those."""
def spkiFromCertificate(der: any) -> any {
    offset: any = read_der(der, 0)[1];
    (_, header, length) = read_der(der, offset);
    (offset, end) = (offset + header, offset + header + length);
    # Skips the optional [0] version, then serial, signature algorithm, issuer, validity, subject.
    for _ in range(6 if globalThis.Reflect.get(der, offset) == 0xa0 else 5) {
        (_, header, length) = read_der(der, offset);
        offset += header + length;
    }
    if offset >= end {
        raise new(globalThis.Error, "Certificate has no public key");
    }
    (_, header, length) = read_der(der, offset);
    return der.subarray(offset, offset + header + length);
}

async def:priv download(url: str) -> any {
    init = record({"redirect": "error", "signal": globalThis.AbortSignal.timeout(5000)});
    got = await globalThis.fetch(url, init);
    if not got.ok {
        raise new(globalThis.Error, f"Signing certificate fetch failed: {got.status}");
    }
    pem = rx_sub(await got.text(), rx(r"-----[A-Z ]+-----", "g"), "");
    der = binary(globalThis.atob(rx_sub(pem, rx(r"\s+", "g"), "")));
    return der.buffer.slice(der.byteOffset, der.byteOffset + der.byteLength);
}

"""One download per certificate URL; a failed one is forgotten so the next message retries."""
def:priv fetch_certificate(url: str) -> any {
    if not CERTS.get(url) {
        pending = promise(download(url));
        CERTS.set(url, pending);
        pending.catch(lambda (error: any) -> any { CERTS.delete(url) });
    }
    return CERTS.get(url);
}

"""Checks the SNS signature against the certificate Amazon published; false on any problem."""
async def verifySnsSignature(envelope: any, options: any = None) -> bool {
    try {
        (version, sig) = (envelope.SignatureVersion, envelope.Signature);
        (url, signed) = (envelope.SigningCertURL, string_to_sign(envelope));
        sent = globalThis.Date.parse(either(envelope.Timestamp, ""));
        ok = version in ("1", "2") and sig and isValidSigningCertUrl(url) and options is not NULL;
        # (A null `options` fails as in TypeScript, which reads `options.now` from it.)
        opts = either(options, {});
        age = globalThis.Math.abs(at(opts, "now", globalThis.Date.now()) - sent);
        if not ok or signed is None or globalThis.Number.isNaN(sent) or age > SNS_MAX_AGE_MS {
            return False;
        }
        load = at(opts, "loadCertificate", fetch_certificate);
        der = new(globalThis.Uint8Array, await load(url));
        (rsa, subtle) = ("RSASSA-PKCS1-v1_5", globalThis.crypto.subtle);
        alg = {"name": rsa, "hash": "SHA-256" if version == "2" else "SHA-1"};
        key = await subtle.importKey("spki", spkiFromCertificate(der), alg, False, ["verify"]);
        text = new(globalThis.TextEncoder).encode(signed);
        return await subtle.verify(rsa, key, binary(globalThis.atob(sig)), text);
    } except Exception {
        return False;
    }
}
