glob:priv ACTION: str = r"(verify|confirm|unlock|restore|validate|sign[ -]?in|log[ -]?in)",
          ASSET: str = r"(account|password|mailbox|identity|access)",
          CREDENTIAL_LURES: list[any] = [
              rx(f"\\b{ACTION}\\b.{{0,60}}\\b{ASSET}\\b", "i"),
              rx(f"\\b{ASSET}\\b.{{0,60}}\\b{ACTION}\\b", "i"),
          ],
          URGENT: any = rx(
              r"\b(urgent|immediately|within 24 hours|suspended|expires? today|final warning)\b",
              "i",
          ),
          PAYMENT_LURE: any = rx(
              r"\b(gift card|wire transfer|cryptocurrency|bitcoin|wallet|bank transfer)\b", "i"
          ),
          PAYMENT_REQUEST: any = rx(r"\b(pay|payment|send|transfer|purchase|deposit)\b", "i"),
          ZERO_WIDTH: any = rx("[\\u200B-\\u200D\\u2060\\uFEFF]", "u"),
          RISKY_FILE: any = rx(r"\.(exe|scr|js|vbs|bat|cmd|iso|img)$", "i"),
          UPPER: any = rx("[A-Z]", "g"),
          LETTER: any = rx("[A-Za-z]", "g");

def:priv count(text: any, regex: any) -> int {
    return globalThis.Array.from(text.matchAll(regex)).length;
}

def:priv blank(text: any) -> bool {
    return not (text and text.trim());
}

def analyzeStructure(message: any, headers: any, prepared: any) -> list[any] {
    visible = prepared["visibleText"];
    from_domain = getDomain(at(message, "fromAddr"));
    reply_domain = getDomain(findHeader(headers, "reply-to"));
    mismatch = bool(reply_domain) and bool(from_domain) and reply_domain != from_domain;
    letters = count(visible, LETTER);
    urgent = URGENT.test(visible);
    risky = [
        attachment
        for attachment in message["attachments"]
        if RISKY_FILE.test(attachment["filename"])
    ];
    checks = [
        (blank(at(message, "subject")), "empty_subject", 3, "Message has no subject"),
        (
            at(message, "html") and blank(at(message, "text")) and visible.trim().length < 80,
            "thin_html_only",
            6,
            "HTML-only message has very little visible text",
        ),
        (
            ZERO_WIDTH.test(visible),
            "zero_width_text",
            7,
            "Message contains hidden zero-width characters",
        ),
        (
            letters > 40 and count(visible, UPPER) / letters > 0.65,
            "excessive_capitals",
            4,
            "Message uses excessive capitalization",
        ),
        (mismatch, "reply_to_mismatch", 5, "Reply-To domain differs from the sender domain"),
        (
            any([lure.test(visible) for lure in CREDENTIAL_LURES])
                and urgent
                and prepared["urlDomains"].length > 0,
            "credential_phishing_pattern",
            24,
            "Message combines an urgent account request with an external link",
        ),
        (
            PAYMENT_LURE.test(visible) and PAYMENT_REQUEST.test(visible) and (urgent or mismatch),
            "payment_scam_pattern",
            16,
            "Message contains a high-risk urgent payment pattern",
        ),
    ];
    signals: list[any] = [
        {"id": id, "score": score, "reason": reason}
        for (hit, id, score, reason) in checks
        if hit
    ];
    if risky {
        signals.append({
            "id": "risky_attachment",
            "score": 10,
            "reason": "Message contains a potentially risky attachment",
            "metadata": {"count": len(risky)},
        });
    }
    return signals;
}
