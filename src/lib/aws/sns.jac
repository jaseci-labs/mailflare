glob:priv API: str = "2010-03-31";

async def listTopics(config: any) {
    await awsQuery(config, "sns", API, "ListTopics");
}

"""Idempotent: creating a topic that exists returns the same ARN."""
async def createTopic(config: any, name: str) -> str {
    arn = xmlTag(await awsQuery(config, "sns", API, "CreateTopic", {"Name": name}), "TopicArn");
    if not arn {
        raise new(globalThis.Error, "SNS did not return a topic ARN");
    }
    return arn;
}

async def setTopicPolicy(config: any, topicArn: str, policy: any) {
    params = {"TopicArn": topicArn, "AttributeName": "Policy"};
    value = globalThis.JSON.stringify(policy);
    await awsQuery(config, "sns", API, "SetTopicAttributes", {**params, "AttributeValue": value});
}

async def subscribeHttps(config: any, topicArn: str, endpoint: str) {
    params = {"TopicArn": topicArn, "Protocol": "https", "Endpoint": endpoint};
    await awsQuery(config, "sns", API, "Subscribe", {**params, "ReturnSubscriptionArn": "true"});
}

async def listSubscriptions(config: any, topicArn: str) -> list[any] {
    xml = await awsQuery(config, "sns", API, "ListSubscriptionsByTopic", {"TopicArn": topicArn});
    fs = [(xmlTag(m, "Endpoint"), xmlTag(m, "SubscriptionArn")) for m in xmlBlocks(xml, "member")];
    fs = [(either(e, ""), bool(a) and a != "PendingConfirmation") for (e, a) in fs];
    return [{"endpoint": e, "confirmed": ok} for (e, ok) in fs];
}
