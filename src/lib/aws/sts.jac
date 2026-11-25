"""Proves the credentials are real and says whose they are."""
async def getCallerIdentity(config: any) -> dict[str, str] {
    xml = await awsQuery(config, "sts", "2011-06-15", "GetCallerIdentity");
    return {"accountId": either(xmlTag(xml, "Account"), ""), "arn": either(xmlTag(xml, "Arn"), "")};
}
