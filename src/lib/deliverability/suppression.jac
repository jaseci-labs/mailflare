import from "drizzle-orm" { and as all_of, eq, gte, inArray, sql }

"""A drizzle `sql` fragment: each `?` of the template is the next value."""
def:priv sqlf(template: str, *values: any) -> any {
    return sql(template.split("?"), *values);
}

glob:priv SETTINGS_ID: str = "default",
          # D1 allows 100 bound parameters per statement; two more are the domain id and the confirmed flag.
          IN_CHUNK: int = 90,
          DSN_LOOKBACK_MS: int = 30 * 24 * 60 * 60 * 1000,
          # Most addresses one returned message may add; real reports name a handful.
          MAX_DSN_ENTRIES: int = 50,
          STRENGTH: dict[str, int] = {"manual": 0, "hard_bounce": 1, "complaint": 2},
          PERMANENT: any = rx(r"^5\.\d+\.\d+$"),
          table: any = emailSuppressions;

"""Installation-wide mode. Reads "off" until the migration that adds the column is applied."""
async def getSuppressionMode(env: any) -> str {
    try {
        rows = await getDb(env).select({"mode": appSettings.suppressionMode}).from(
            appSettings
        ).where(eq(appSettings.id, SETTINGS_ID)).limit(1);
        return rows[0].mode if rows.length and rows[0].mode in ["record", "enforce"] else "off";
    } except Exception {
        return "off";
    }
}

async def setSuppressionMode(env: any, mode: str) {
    values = {"suppressionMode": mode, "updatedAt": new(globalThis.Date)};
    await getDb(env).insert(appSettings).values({"id": SETTINGS_ID, **values}).onConflictDoUpdate({
        "target": appSettings.id,
        "set": values,
    });
}

async def domainIdForAddress(env: any, address: any) -> any {
    email = cleanAddress(address);
    if not email {
        return NULL;
    }
    rows = await getDb(env).select({"id": domains.id}).from(domains).where(
        eq(domains.hostname, addressDomain(email))
    ).limit(1);
    return either(rows[0].id, NULL) if rows.length else NULL;
}

"""
Inserts or updates one address for a domain. The reason never gets weaker (complaint beats
hard_bounce beats manual), and a weaker event neither replaces the stronger entry's source and
detail nor, for a manual entry, counts as another event.

Only `confirmed` entries are enforced (default). An unconfirmed one (a DSN, or a Resend event naming
several recipients) becomes confirmed when a later confirmed event arrives, when a DSN names the
same address for a different original message (`evidenceRef`), or through `confirmSuppression`.
An unconfirmed event never alters an entry that is already confirmed, beyond counting.
"""
async def recordSuppression(env: any, input: any) {
    now = new(globalThis.Date);
    (reason, detail) = (input["reason"], at(input, "detail"));
    detail = NULL if nil(detail) else detail.slice(0, MAX_SUPPRESSION_DETAIL);
    stronger = [name for name in STRENGTH if STRENGTH[name] > STRENGTH[reason]];
    confirmed = at(input, "confirmed") is not False;
    evidence = NULL if confirmed else at(input, "evidenceRef", NULL);
    keep: any = sqlf(
        "? in (?)", table.reason, sql.join([sqlf("?", name) for name in stronger], sqlf(", "))
    )
        if stronger
        else None;
    if not confirmed {
        keep = sqlf("(? or ?)", keep, table.confirmed) if keep else sqlf("?", table.confirmed);
    }

    def choose(column: any, value: any) -> any {
        return sqlf("case when ? then ? else ? end", keep, column, value) if keep else value;
    }
    still_confirmed: any = True
        if confirmed
        else sqlf(
            "(? or (? is not null and ? <> ?))",
            table.confirmed,
            table.evidenceRef,
            table.evidenceRef,
            evidence,
        )
            if evidence
            else sqlf("?", table.confirmed);
    counted: dict[str, any] = {}
        if reason == "manual"
        else {"eventCount": sqlf("? + 1", table.eventCount), "lastEventAt": now};
    await getDb(env).insert(table).values({
        "id": newId("sup"),
        "domainId": input["domainId"],
        "email": input["email"],
        "reason": reason,
        "source": input["source"],
        "detail": detail,
        "confirmed": confirmed,
        "evidenceRef": evidence,
        "firstEventAt": now,
        "lastEventAt": now,
        "createdByUserId": at(input, "userId", NULL),
    }).onConflictDoUpdate({
        "target": [table.domainId, table.email],
        "set": {
            "reason": choose(table.reason, reason),
            "source": choose(table.source, input["source"]),
            "detail": choose(table.detail, detail),
            "confirmed": still_confirmed,
            **counted,
        },
    });
}

"""Records verified provider events for the sender's domain. Mode "off" and unknown domains record nothing."""
async def recordSuppressionEvents(env: any, input: any) -> int {
    if await getSuppressionMode(env) == "off" {
        return 0;
    }
    domain_id = await domainIdForAddress(env, input["sender"]);
    if not domain_id {
        return 0;
    }
    for item in input["entries"] {
        await recordSuppression(
            env,
            {
                "domainId": domain_id,
                "email": item["email"],
                "reason": item["reason"],
                "source": input["source"],
                "detail": at(item, "detail"),
                "confirmed": not at(item, "unconfirmed"),
            },
        );
    }
    return len(input["entries"]);
}

"""Which of the addresses are suppressed (and confirmed, so enforceable) for the domain."""
async def findSuppressed(env: any, domainId: str, emails: any) -> any {
    found = new(globalThis.Set);
    unique: list[str] = [];
    for email in emails {
        address = cleanAddress(email);
        if address and address not in unique {
            unique.append(address);
        }
    }
    for offset in range(0, len(unique), IN_CHUNK) {
        rows = await getDb(env).select({"email": table.email}).from(table).where(
            all_of(
                eq(table.domainId, domainId),
                eq(table.confirmed, True),
                inArray(table.email, unique[offset:offset + IN_CHUNK]),
            ),
        );
        for row in rows {
            found.add(row.email);
        }
    }
    return found;
}

"""
A returned message counts only when it names a Message-ID of a message we sent from this mailbox
in the last 30 days, and only for recipients we actually wrote to. Anyone can mail a mailbox a
forged bounce; this is what stops it from suppressing arbitrary addresses.

That check is not enough on its own: a co-recipient of a message we sent has its Message-ID and the
other addresses, so it can forge a DSN for them. A DSN entry is therefore stored unconfirmed and
enforced only once a second DSN names the same address for a different original message, or an
admin confirms it. Mode "off" returns before the message is parsed.
"""
async def recordDsnBounces(env: any, input: any) -> int {
    if await getSuppressionMode(env) == "off" {
        return 0;
    }
    status = parseDeliveryStatus(input["raw"]);
    if not status or not status["originalMessageId"] {
        return 0;
    }
    failed = [
        recipient
        for recipient in status["recipients"]
        if recipient["action"] == "failed" and PERMANENT.test(recipient["status"])
    ];
    if not failed {
        return 0;
    }
    id = status["originalMessageId"];
    rows = await getDb(env).select({
        "sender": messages.fromAddr,
        "to": messages.toAddr,
        "cc": messages.ccAddr,
        "bcc": messages.bccAddr,
    }).from(messages).where(
        all_of(
            eq(messages.mailboxId, input["mailboxId"]),
            eq(messages.direction, "outbound"),
            inArray(messages.providerMessageId, [id, f"<{id}>"]),
            gte(messages.createdAt, new(globalThis.Date, globalThis.Date.now() - DSN_LOOKBACK_MS)),
        ),
    ).limit(1);
    if not rows.length {
        return 0;
    }
    sent = rows[0];
    domain_id = await domainIdForAddress(env, sent.sender);
    if not domain_id {
        return 0;
    }
    written = getEmailAddressList(
        ", ".join([line for line in [sent.to, sent.cc, sent.bcc] if line])
    );
    found: dict[str, str] = {};
    for recipient in failed {
        email = cleanAddress(recipient["finalRecipient"]);
        if email and email in written and email not in found and len(found) < MAX_DSN_ENTRIES {
            found[email] = recipient["diagnostic"];
        }
    }
    for (email, diagnostic) in found.items() {
        await recordSuppression(
            env,
            {
                "domainId": domain_id,
                "email": email,
                "reason": "hard_bounce",
                "source": "dsn",
                "detail": diagnostic,
                "confirmed": False,
                "evidenceRef": id,
            },
        );
    }
    return len(found);
}

"""Suppressed addresses among the recipients; always empty unless the mode is "enforce"."""
async def:priv enforced_suppressions(env: any, sender: any, recipients: any) -> any {
    if await getSuppressionMode(env) != "enforce" {
        return new(globalThis.Set);
    }
    domain_id = await domainIdForAddress(env, sender);
    return await findSuppressed(env, domain_id, recipients) if domain_id else new(globalThis.Set);
}

"""Refuses a send to any suppressed recipient of the sending domain (mode "enforce" only)."""
async def assertNoSuppressedRecipients(env: any, sender: any, recipients: any) {
    suppressed = await enforced_suppressions(env, sender, recipients);
    if not suppressed.size {
        return;
    }
    blocked: list[str] = [];
    for recipient in recipients {
        address = cleanAddress(recipient);
        if address and suppressed.has(address) and address not in blocked {
            blocked.append(address);
        }
    }
    raise SuppressedRecipientError(blocked);
}

"""Same refusal for features that store something before sending (calendar invitations): call it first, so nothing is half-done."""
async def assertInviteesAllowed(env: any, input: any) {
    sender = await getAuthorizedSenderAddress(env, input);
    await assertNoSuppressedRecipients(env, sender["fromAddr"], input["attendees"]);
}

"""Delivery-time twin of the check above: removes suppressed recipients instead of refusing."""
async def dropSuppressedRecipients(env: any, sender: any, lists: any) -> any {
    parts = [lists["to"], lists["cc"], lists["bcc"]];
    suppressed = await enforced_suppressions(
        env, sender, [address for part in parts for address in part]
    );
    if not suppressed.size {
        return merged(lists, {"dropped": []});
    }
    (to, cc, bcc) = [filterSuppressed(part, suppressed) for part in parts];
    dropped: list[str] = [];
    for address in to["suppressed"] + cc["suppressed"] + bcc["suppressed"] {
        if address not in dropped {
            dropped.append(address);
        }
    }
    return {"to": to["allowed"], "cc": cc["allowed"], "bcc": bcc["allowed"], "dropped": dropped};
}
