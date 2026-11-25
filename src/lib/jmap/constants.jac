glob CAPABILITY_CORE = "urn:ietf:params:jmap:core",
     CAPABILITY_MAIL = "urn:ietf:params:jmap:mail",
     CAPABILITY_SUBMISSION = "urn:ietf:params:jmap:submission",
     LIMITS: any = record({
         "maxSizeUpload": 10 * 1024 * 1024,
         "maxSizeRequest": 10 * 1024 * 1024,
         "maxCallsInRequest": 32,
         "maxObjectsInGet": 200,
         "maxObjectsInSet": 100,
         "maxSizeAttachmentsPerEmail": 20 * 1024 * 1024,
         # Email/query never returns more than this many ids per call.
         "maxQueryLimit": 250,
     }),
     KEYWORD_SEEN = "$seen",
     KEYWORD_FLAGGED = "$flagged",
     KEYWORD_DRAFT = "$draft",
     # Read-only, set while in Promotions; clients cannot write it; Inbox is unchanged in every mode.
     KEYWORD_PROMOTION = "$promotion";
