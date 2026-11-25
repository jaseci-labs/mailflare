glob SNS_MAX_AGE_MS: int = 24 * 60 * 60 * 1000;

glob:priv CERT_HOST: any = rx(r"^sns\.[a-z0-9-]+\.amazonaws\.com(?:\.cn)?$"),
          PEM_ARMOR: any = rx(r"-----[A-Z ]+-----", "g"),
          SPACES: any = rx(r"\s+", "g"),
          CERT_CACHE: any = new(globalThis.Map),
          CONFIRMATION_FIELDS: list[str] = [
              "Message",
              "MessageId",
              "SubscribeURL",
              "Timestamp",
              "Token",
              "TopicArn",
              "Type",
          ],
          # The fields SNS signs, in the order it signs them (Amazon SNS "Verifying the signatures" docs).
          SIGNED_FIELDS: dict[str, list[str]] = {
              "Notification": ["Message", "MessageId", "Subject", "Timestamp", "TopicArn", "Type"],
              "SubscriptionConfirmation": CONFIRMATION_FIELDS,
              "UnsubscribeConfirmation": CONFIRMATION_FIELDS,
          };

"""`o.k` as it is, null included, of a Jac dict or a JavaScript object."""
def:priv raw(o: any, k: str) -> any {
    return o.get(k) if isinstance(o, dict) else getattr(o, k, None);
}

def:priv string_to_sign(envelope: any) -> str | None {
    kind = raw(envelope, "Type");
    if not isinstance(kind, str) or kind not in SIGNED_FIELDS {
        return None;
    }
    out = "";
    for key in SIGNED_FIELDS[kind] {
        value = raw(envelope, key);
        if value is not None {
            out += key + "\n" + globalThis.String(value) + "\n";
        } elif key != "Subject" {
            return None;
        }
    }
    return out;
}

def isValidSigningCertUrl(value: any = None) -> bool {
    if not value {
        return False;
    }
    try {
        url = new(globalThis.URL, value);
        return url.protocol == "https:"
            and not url.port
            and CERT_HOST.test(url.hostname)
            and url.pathname.endsWith(".pem");
    } except Exception {
        return False;
    }
}

def:priv binary(text: any) -> any {
    return new(globalThis.Uint8Array, [char.charCodeAt(0) for char in text]);
}

def:priv pem_to_der(pem: str) -> any {
    return binary(globalThis.atob(rx_sub(rx_sub(pem, PEM_ARMOR, ""), SPACES, "")));
}

"""`octets[i]` as JavaScript reads it: undefined past the end."""
def:priv octet(octets: any, i: any) -> any {
    return globalThis.Reflect.get(octets, i);
}

"""Reads one DER element at `offset`: its tag, header length and content length."""
def:priv read_der(octets: any, offset: any) -> tuple[any, any, any] {
    (tag, first) = (octet(octets, offset), octet(octets, offset + 1));
    if first is None {
        return (tag, 2, 0);
    }
    if first < 0x80 {
        return (tag, 2, first);
    }
    count = first & 0x7f;
    length: any = 0;
    for index in range(count) {
        length = length * 256 + either(octet(octets, offset + 2 + index), globalThis.NaN);
    }
    return (tag, 2 + count, length);
}

"""Pulls the SubjectPublicKeyInfo out of an X.509 certificate; Web Crypto cannot import certificates."""
def spkiFromCertificate(der: any) -> any {
    offset: any = read_der(der, 0)[1];
    (_, header, length) = read_der(der, offset);
    offset += header;
    tbs_end = offset + length;
    # Skipped: the optional [0] version, then serial, signature algorithm, issuer, validity, subject.
    for _ in range(6 if octet(der, offset) == 0xa0 else 5) {
        (_, header, length) = read_der(der, offset);
        offset += header + length;
    }
    if offset >= tbs_end {
        raise new(globalThis.Error, "Certificate has no public key");
    }
    (_, header, length) = read_der(der, offset);
    return der.subarray(offset, offset + header + length);
}

async def:priv download_certificate(url: str) -> any {
    response = await globalThis.fetch(
        url, record({"redirect": "error", "signal": globalThis.AbortSignal.timeout(5000)})
    );
    if not response.ok {
        raise new(globalThis.Error, f"Signing certificate fetch failed: {response.status}");
    }
    der = pem_to_der(await response.text());
    return der.buffer.slice(der.byteOffset, der.byteOffset + der.byteLength);
}

"""One download per certificate URL; a failed one is forgotten so the next message retries."""
def:priv fetch_certificate(url: str) -> any {
    cached = CERT_CACHE.get(url);
    if cached {
        return cached;
    }
    # Called through JavaScript to get a promise that is running: a plain call gives a coroutine,
    # which starts only when awaited and can be awaited once.
    pending: any = globalThis.Reflect.apply(download_certificate, None, [url]);
    CERT_CACHE.set(url, pending);
    pending.catch(lambda (error: any) -> any { CERT_CACHE.delete(url) });
    return pending;
}

"""Checks the SNS signature against the certificate Amazon published. Returns false on any problem."""
async def verifySnsSignature(envelope: any, options: any = None) -> bool {
    try {
        if options is NULL {
            return False;
        }
        options = either(options, {});
        (version, signature, cert_url) = (
            raw(envelope, "SignatureVersion"),
            raw(envelope, "Signature"),
            raw(envelope, "SigningCertURL"),
        );
        if version not in ("1", "2") or not signature or not isValidSigningCertUrl(cert_url) {
            return False;
        }
        signed = string_to_sign(envelope);
        sent_at = globalThis.Date.parse(either(raw(envelope, "Timestamp"), ""));
        if signed is None
            or globalThis.Number.isNaN(sent_at)
            or globalThis.Math.abs(at(options, "now", globalThis.Date.now()) - sent_at)
                > SNS_MAX_AGE_MS
        {
            return False;
        }
        load = at(options, "loadCertificate", fetch_certificate);
        key = await globalThis.crypto.subtle.importKey(
            "spki",
            spkiFromCertificate(new(globalThis.Uint8Array, await load(cert_url))),
            {"name": "RSASSA-PKCS1-v1_5", "hash": "SHA-256" if version == "2" else "SHA-1"},
            False,
            ["verify"],
        );
        return await globalThis.crypto.subtle.verify(
            "RSASSA-PKCS1-v1_5",
            key,
            binary(globalThis.atob(signature)),
            new(globalThis.TextEncoder).encode(signed),
        );
    } except Exception {
        return False;
    }
}
