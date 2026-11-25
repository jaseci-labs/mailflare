"""The AwsError a failed call threw, else None. Jac hands `except` a wrapper of a JavaScript error, the original in `js`."""
def:priv aws_error(caught: any) -> any {
    error = thrown(caught);
    return error if isinstance(error, AwsError) else None;
}

def:priv thrown(caught: any) -> any {
    return getattr(caught, "js", caught);
}

"""`o?.a?.b`: undefined once a link is missing."""
def:priv dig(o: any, *path: str) -> any {
    for key in path {
        if nil(o) {
            return None;
        }
        o = getattr(o, key, None);
    }
    return o;
}

# --- SES v2 (sending, identities) -------------------------------------------------

def:priv ses_v2(config: any, path: str, **more: any) -> dict[str, any] {
    return {
        "config": config,
        "service": "ses",
        "host": f"email.{config['region']}.amazonaws.com",
        "path": path,
        **more,
    };
}

def:priv identity_path(hostname: str) -> str {
    return f"/v2/email/identities/{globalThis.encodeURIComponent(hostname)}";
}

async def getSesAccount(config: any) -> dict[str, bool] {
    account = await awsJson(ses_v2(config, "/v2/email/account"));
    return {
        "productionAccess": bool(dig(account, "ProductionAccessEnabled")),
        "sendingEnabled": dig(account, "SendingEnabled") is not False,
    };
}

def:priv identity_status(hostname: str, identity: any) -> dict[str, any] {
    if not identity {
        return {
            "registered": False,
            "verified": False,
            "dkimStatus": "NOT_REGISTERED",
            "records": [],
        };
    }
    return {
        "registered": True,
        "verified": bool(dig(identity, "VerifiedForSendingStatus")),
        "dkimStatus": either(dig(identity, "DkimAttributes", "Status"), "NOT_STARTED"),
        "records": [
            {
                "type": "CNAME",
                "name": f"{token}._domainkey.{hostname}",
                "value": f"{token}.dkim.amazonses.com",
            }
            for token in either(dig(identity, "DkimAttributes", "Tokens"), [])
        ],
    };
}

async def getSesIdentity(config: any, hostname: str) -> dict[str, any] {
    try {
        return identity_status(hostname, await awsJson(ses_v2(config, identity_path(hostname))));
    } except Exception as caught {
        failure = aws_error(caught);
        if failure and (failure.code == "NotFoundException" or failure.status == 404) {
            return identity_status(hostname, None);
        }
        raise thrown(caught);
    }
}

async def createSesIdentity(config: any, hostname: str) -> dict[str, any] {
    try {
        return identity_status(
            hostname,
            await awsJson(
                ses_v2(
                    config,
                    "/v2/email/identities",
                    method="POST",
                    json={
                        "EmailIdentity": hostname,
                        "DkimSigningAttributes": {"NextSigningKeyLength": "RSA_2048_BIT"},
                    },
                ),
            ),
        );
    } except Exception as caught {
        failure = aws_error(caught);
        if failure and failure.code == "AlreadyExistsException" {
            return await getSesIdentity(config, hostname);
        }
        raise thrown(caught);
    }
}

async def deleteSesIdentity(config: any, hostname: str) {
    try {
        await awsJson(ses_v2(config, identity_path(hostname), method="DELETE"));
    } except Exception as caught {
        failure = aws_error(caught);
        if not (failure and failure.status == 404) {
            raise thrown(caught);
        }
    }
}

def:priv to_base64(buffer: any) -> str {
    octets = new(globalThis.Uint8Array, buffer);
    # In slices: one call with every byte as an argument overflows the stack on a large attachment.
    return globalThis.btoa(
        "".join([
            globalThis.String.fromCharCode.apply(None, octets.subarray(offset, offset + 0x8000))
            for offset in range(0, octets.length, 0x8000)
        ]),
    );
}

def:priv utf8(data: any) -> dict[str, any] {
    return {"Data": data, "Charset": "UTF-8"};
}

def:priv ses_attachment(attachment: any) -> dict[str, any] {
    inline = attachment["disposition"] == "inline";
    content_id = at(attachment, "contentId");
    return {
        "RawContent": to_base64(attachment["content"]),
        "FileName": attachment["filename"],
        "ContentType": attachment["type"],
        "ContentDisposition": "INLINE" if inline else "ATTACHMENT",
        **({"ContentId": content_id} if inline and content_id else {}),
        "ContentTransferEncoding": "BASE64",
    };
}

"""
`input` is { from, to, cc?, bcc?, subject, html?, text?, headers?, attachments? }; an attachment is
{ filename, type, content (ArrayBuffer), disposition ("attachment" or "inline"), contentId? }.
"""
async def sendSesEmail(config: any, input: any) -> dict[str, str] {
    headers = [
        {"Name": name, "Value": value}
        for (name, value) in entries(at(input, "headers", {}))
        if name.toLowerCase() != "message-id"
    ];
    (cc, bcc, text, html, attachments) = (
        at(input, "cc"),
        at(input, "bcc"),
        at(input, "text"),
        at(input, "html"),
        at(input, "attachments"),
    );
    result = await awsJson(
        ses_v2(
            config,
            "/v2/email/outbound-emails",
            method="POST",
            json={
                "FromEmailAddress": input["from"],
                "Destination": {
                    "ToAddresses": input["to"],
                    **({"CcAddresses": cc} if cc else {}),
                    **({"BccAddresses": bcc} if bcc else {}),
                },
                "Content": {
                    "Simple": {
                        "Subject": utf8(input["subject"]),
                        "Body": {
                            **({"Text": utf8(text)} if text else {}),
                            **({"Html": utf8(html)} if html else {}),
                        },
                        **({"Headers": headers} if headers else {}),
                        **(
                            {
                                "Attachments": [
                                    ses_attachment(attachment)
                                    for attachment in attachments
                                ],
                            }
                                if attachments
                                else {}
                        ),
                    },
                },
            },
        ),
    );
    # SES rewrites Message-ID to <id@email.amazonses.com> (us-east-1) or <id@region.amazonses.com>.
    region = config["region"];
    domain = "email.amazonses.com" if region == "us-east-1" else f"{region}.amazonses.com";
    return {"messageId": "<" + globalThis.String(result["MessageId"]) + f"@{domain}>"};
}

# --- SES v1 (receipt rules; not available in v2) ---------------------------------

async def:priv query(config: any, action: str, params: any = None) -> str {
    return await awsQuery(
        config,
        "email",
        "2010-12-01",
        action,
        either(params, {}),
        {"host": f"email.{config['region']}.amazonaws.com", "signingService": "ses"},
    );
}

"""SES v1: routes Bounce or Complaint notifications of an identity to an SNS topic; a null topic detaches it."""
async def setIdentityNotificationTopic(
    config: any, identity: str, kind: str, topicArn: any = None
) {
    await query(
        config,
        "SetIdentityNotificationTopic",
        {
            "Identity": identity,
            "NotificationType": kind,
            **({"SnsTopic": topicArn} if topicArn else {}),
        },
    );
}

async def describeActiveRuleSet(config: any) -> dict[str, any] {
    xml = await query(config, "DescribeActiveReceiptRuleSet");
    first = lambda (blocks: list[str]) -> str { blocks[0] if blocks else "" };
    names = [
        xmlTag(member, "Name")
        for member in xmlBlocks(first(xmlBlocks(xml, "Rules")), "member")
    ];
    return {
        "name": xmlTag(first(xmlBlocks(xml, "Metadata")), "Name"),
        "rules": [name for name in names if name],
    };
}

async def createRuleSet(config: any, name: str) {
    try {
        await query(config, "CreateReceiptRuleSet", {"RuleSetName": name});
    } except Exception as caught {
        failure = aws_error(caught);
        if not (failure and failure.code == "AlreadyExists") {
            raise thrown(caught);
        }
    }
}

async def activateRuleSet(config: any, name: str) {
    await query(config, "SetActiveReceiptRuleSet", {"RuleSetName": name});
}

"""`input` is { ruleSet, name, recipient, bucket, prefix, topicArn }."""
def:priv rule_params(input: any) -> dict[str, any] {
    return {
        "RuleSetName": input["ruleSet"],
        "Rule.Name": input["name"],
        "Rule.Enabled": "true",
        "Rule.ScanEnabled": "true",
        "Rule.TlsPolicy": "Optional",
        "Rule.Recipients.member.1": input["recipient"],
        "Rule.Actions.member.1.S3Action.BucketName": input["bucket"],
        "Rule.Actions.member.1.S3Action.ObjectKeyPrefix": input["prefix"],
        "Rule.Actions.member.1.S3Action.TopicArn": input["topicArn"],
    };
}

async def upsertReceiptRule(config: any, input: any) {
    try {
        await query(config, "CreateReceiptRule", rule_params(input));
    } except Exception as caught {
        failure = aws_error(caught);
        if not (failure and failure.code == "AlreadyExists") {
            raise thrown(caught);
        }
        await query(config, "UpdateReceiptRule", rule_params(input));
    }
}

def:priv is_missing_rule(caught: any) -> bool {
    failure = aws_error(caught);
    return bool(failure) and globalThis.String(failure.code).includes("DoesNotExist");
}

async def describeReceiptRule(config: any, ruleSet: str, name: str) -> bool {
    try {
        await query(config, "DescribeReceiptRule", {"RuleSetName": ruleSet, "RuleName": name});
        return True;
    } except Exception as caught {
        if is_missing_rule(caught) {
            return False;
        }
        raise thrown(caught);
    }
}

async def deleteReceiptRule(config: any, ruleSet: str, name: str) {
    try {
        await query(config, "DeleteReceiptRule", {"RuleSetName": ruleSet, "RuleName": name});
    } except Exception as caught {
        if not is_missing_rule(caught) {
            raise thrown(caught);
        }
    }
}
