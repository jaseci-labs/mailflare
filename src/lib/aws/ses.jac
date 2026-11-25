def:priv v2(config: any, path: str, m: any = None, j: any = None) -> any {
    h = f"email.{config['region']}.amazonaws.com";
    return {"config": config, "service": "ses", "host": h, "path": path, "method": m, "json": j};
}

def:priv identity_path(host: str) -> str {
    return "/v2/email/identities/" + globalThis.encodeURIComponent(host);
}

async def getSesAccount(config: any) -> any {
    got = await awsJson(v2(config, "/v2/email/account"));
    ok = at(got, "SendingEnabled") is not False;
    return {"productionAccess": bool(at(got, "ProductionAccessEnabled")), "sendingEnabled": ok};
}

def:priv identity_status(host: str, it: any) -> any {
    dkim = at(it, "DkimAttributes") if it else None;
    status = dig(dkim, ["Status"], "NOT_STARTED") if it else "NOT_REGISTERED";
    records = [
        {"type": "CNAME", "name": f"{t}._domainkey.{host}", "value": f"{t}.dkim.amazonses.com"}
        for t in dig(dkim, ["Tokens"], [])
    ];
    verified = bool(it) and bool(at(it, "VerifiedForSendingStatus"));
    return {"registered": bool(it), "verified": verified, "dkimStatus": status, "records": records};
}

async def getSesIdentity(config: any, host: str) -> any {
    found = awsJson(v2(config, identity_path(host)));
    return identity_status(host, await awsSpare(found, "NotFoundException", 404));
}

async def createSesIdentity(config: any, host: str) -> any {
    key = {"NextSigningKeyLength": "RSA_2048_BIT"};
    body = {"EmailIdentity": host, "DkimSigningAttributes": key};
    call = awsJson(v2(config, "/v2/email/identities", "POST", body));
    made = await awsSpare(call, "AlreadyExistsException");
    return identity_status(host, made) if made is not None else await getSesIdentity(config, host);
}

async def deleteSesIdentity(config: any, host: str) {
    await awsSpare(awsJson(v2(config, identity_path(host), "DELETE")), status=404);
}

def:priv base64(buffer: any) -> str {
    b = new(globalThis.Uint8Array, buffer);
    # In slices: one call with every byte as an argument overflows the stack.
    f = globalThis.String.fromCharCode;
    parts = [f.apply(None, b.subarray(i, i + 0x8000)) for i in range(0, b.length, 0x8000)];
    return globalThis.btoa("".join(parts));
}

def:priv utf8(data: any) -> any {
    return {"Data": data, "Charset": "UTF-8"};
}

def:priv attachment(a: any) -> any {
    inline = a["disposition"] == "inline";
    cid = at(a, "contentId") if inline and at(a, "contentId") else None;
    (kind, encoded) = ("INLINE" if inline else "ATTACHMENT", base64(a["content"]));
    o = {"RawContent": encoded, "FileName": a["filename"], "ContentType": a["type"]};
    return {**o, "ContentDisposition": kind, "ContentId": cid, "ContentTransferEncoding": "BASE64"};
}

"""`input` is { from, to, cc?, bcc?, subject, html?, text?, headers?, attachments? }."""
async def sendSesEmail(config: any, input: any) -> any {
    (cc, bcc, files) = (at(input, "cc"), at(input, "bcc"), at(input, "attachments"));
    (text, html, hs) = (at(input, "text"), at(input, "html"), entries(at(input, "headers", {})));
    headers = [{"Name": k, "Value": v} for (k, v) in hs if k.lower() != "message-id"];
    to = {"ToAddresses": input["to"], "CcAddresses": cc or None, "BccAddresses": bcc or None};
    body = {"Text": utf8(text) if text else None, "Html": utf8(html) if html else None};
    simple = {"Subject": utf8(input["subject"]), "Body": body, "Headers": headers or None};
    simple["Attachments"] = [attachment(a) for a in files] if files else None;
    mail = {"FromEmailAddress": input["from"], "Destination": to, "Content": {"Simple": simple}};
    result = await awsJson(v2(config, "/v2/email/outbound-emails", "POST", mail));
    # SES rewrites Message-ID to <id@email.amazonses.com> (us-east-1) or <id@region.amazonses.com>.
    region = config["region"];
    domain = "email.amazonses.com" if region == "us-east-1" else f"{region}.amazonses.com";
    return {"messageId": "<" + globalThis.String(result["MessageId"]) + f"@{domain}>"};
}

async def:priv query(config: any, action: str, params: any = None) -> str {
    opts = {"host": f"email.{config['region']}.amazonaws.com", "signingService": "ses"};
    return await awsQuery(config, "email", "2010-12-01", action, params, opts);
}

"""SES v1: sends an identity's Bounce or Complaint notifications to an SNS topic; null detaches."""
async def setIdentityNotificationTopic(config: any, identity: str, kind: str, arn: any = None) {
    sns = {"SnsTopic": arn} if arn else {};
    params = {"Identity": identity, "NotificationType": kind, **sns};
    await query(config, "SetIdentityNotificationTopic", params);
}

async def describeActiveRuleSet(config: any) -> any {
    xml = await query(config, "DescribeActiveReceiptRuleSet");
    rules = [xmlTag(m, "Name") for m in xmlBlocks("".join(xmlBlocks(xml, "Rules")[:1]), "member")];
    name = xmlTag("".join(xmlBlocks(xml, "Metadata")[:1]), "Name");
    return {"name": name, "rules": [r for r in rules if r]};
}

async def createRuleSet(config: any, name: str) {
    await awsSpare(query(config, "CreateReceiptRuleSet", {"RuleSetName": name}), "AlreadyExists");
}

async def activateRuleSet(config: any, name: str) {
    await query(config, "SetActiveReceiptRuleSet", {"RuleSetName": name});
}

# `A.` is the rule's S3 action; a value `:k` is the input's `k`.
glob:priv RULE: str = """RuleSetName=:ruleSet Rule.Name=:name Rule.Enabled=true
    Rule.ScanEnabled=true Rule.TlsPolicy=Optional Rule.Recipients.member.1=:recipient
    A.BucketName=:bucket A.ObjectKeyPrefix=:prefix A.TopicArn=:topicArn""";

"""`input` is { ruleSet, name, recipient, bucket, prefix, topicArn }."""
def:priv rule(input: any) -> any {
    s3 = "Rule.Actions.member.1.S3Action.";
    pairs: any = [p.split("=") for p in RULE.split()];
    return {k.replace("A.", s3): input[v[1:]] if v.startswith(":") else v for (k, v) in pairs};
}

async def upsertReceiptRule(config: any, input: any) {
    if await awsSpare(query(config, "CreateReceiptRule", rule(input)), "AlreadyExists") is None {
        await query(config, "UpdateReceiptRule", rule(input));
    }
}

async def describeReceiptRule(config: any, ruleSet: str, name: str) -> bool {
    found = query(config, "DescribeReceiptRule", {"RuleSetName": ruleSet, "RuleName": name});
    return await awsSpare(found, ".*DoesNotExist.*") is not None;
}

async def deleteReceiptRule(config: any, ruleSet: str, name: str) {
    gone = query(config, "DeleteReceiptRule", {"RuleSetName": ruleSet, "RuleName": name});
    await awsSpare(gone, ".*DoesNotExist.*");
}
