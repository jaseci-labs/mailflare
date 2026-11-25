async def:priv query(config: any, action: str, params: any = None) -> str {
    return await awsQuery(config, "sns", "2010-03-31", action, either(params, {}));
}

async def listTopics(config: any) {
    await query(config, "ListTopics");
}

"""Idempotent: creating a topic that exists returns the same ARN."""
async def createTopic(config: any, name: str) -> str {
    arn = xmlTag(await query(config, "CreateTopic", {"Name": name}), "TopicArn");
    if not arn {
        raise new(globalThis.Error, "SNS did not return a topic ARN");
    }
    return arn;
}

async def setTopicPolicy(config: any, topicArn: str, policy: any) {
    await query(
        config,
        "SetTopicAttributes",
        {
            "TopicArn": topicArn,
            "AttributeName": "Policy",
            "AttributeValue": globalThis.JSON.stringify(policy),
        },
    );
}

async def subscribeHttps(config: any, topicArn: str, endpoint: str) {
    await query(
        config,
        "Subscribe",
        {
            "TopicArn": topicArn,
            "Protocol": "https",
            "Endpoint": endpoint,
            "ReturnSubscriptionArn": "true",
        },
    );
}

def:priv subscription(member: str) -> dict[str, any] {
    arn = xmlTag(member, "SubscriptionArn");
    return {
        "endpoint": either(xmlTag(member, "Endpoint"), ""),
        "confirmed": bool(arn) and arn != "PendingConfirmation",
    };
}

async def listSubscriptions(config: any, topicArn: str) -> list[any] {
    xml = await query(config, "ListSubscriptionsByTopic", {"TopicArn": topicArn});
    return [subscription(member) for member in xmlBlocks(xml, "member")];
}
