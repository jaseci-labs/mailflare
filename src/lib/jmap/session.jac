# The Session object (RFC 8620 §2). One account per API key: the key's user.
def buildSession(ctx: any, sessionState: str) -> dict[str, any] {
    base = f"{ctx.origin}/jmap";
    return {
        "capabilities": {
            CAPABILITY_CORE: {
                "maxSizeUpload": LIMITS.maxSizeUpload,
                "maxConcurrentUpload": 4,
                "maxSizeRequest": LIMITS.maxSizeRequest,
                "maxConcurrentRequests": 4,
                "maxCallsInRequest": LIMITS.maxCallsInRequest,
                "maxObjectsInGet": LIMITS.maxObjectsInGet,
                "maxObjectsInSet": LIMITS.maxObjectsInSet,
                "collationAlgorithms": ["i;ascii-casemap", "i;unicode-casemap"],
            },
            CAPABILITY_MAIL: {},
            CAPABILITY_SUBMISSION: {},
        },
        "accounts": {
            ctx.accountId: {
                "name": ctx.auth.email,
                "isPersonal": True,
                "isReadOnly": False,
                "accountCapabilities": {
                    CAPABILITY_MAIL: {
                        "maxMailboxesPerEmail": 1,
                        "maxMailboxDepth": 2,
                        "maxSizeMailboxName": 80,
                        "maxSizeAttachmentsPerEmail": LIMITS.maxSizeAttachmentsPerEmail,
                        "emailQuerySortOptions": "receivedAt sentAt subject from size hasKeyword".split(),
                        "mayCreateTopLevelMailbox": False,
                    },
                    CAPABILITY_SUBMISSION: {"maxDelayedSend": 0, "submissionExtensions": {}},
                },
            },
        },
        "primaryAccounts": {CAPABILITY_MAIL: ctx.accountId, CAPABILITY_SUBMISSION: ctx.accountId},
        "username": ctx.auth.email,
        "apiUrl": f"{base}/api",
        "downloadUrl": f"{base}/download/{{accountId}}/{{blobId}}/{{name}}?type={{type}}",
        "uploadUrl": f"{base}/upload/{{accountId}}",
        "eventSourceUrl": f"{base}/eventsource?types={{types}}&closeafter={{closeafter}}&ping={{ping}}",
        "state": sessionState,
    };
}
