# SPAM_STRICTNESS_THRESHOLDS is per user: the score that moves a message to Spam. "normal" equals
# SPAM_THRESHOLDS.spam; the database default is "strict". `unknownSenderPassScale` is what passes
# count for a first contact; saved or written-to contacts, good reputation and recurring senders
# get all of it.
glob SPAM_THRESHOLDS: any = record({"suspicious": 40, "spam": 70}),
     SPAM_STRICTNESS_THRESHOLDS: any = record({"relaxed": 85, "normal": 70, "strict": 55}),
     SPAM_STRICTNESS_LEVELS: list[str] = ["relaxed", "normal", "strict"],
     SPAM_WEIGHTS: any = globalThis.JSON.parse("""{"authentication": {"dmarcFail": 18,
         "dmarcPass": -8, "dkimFail": 8, "dkimPass": -4, "spfFail": 6, "spfPass": -2,
         "unknownSenderPassScale": 0.5},
         "relationships": {"manuallySavedContact": -15, "previouslySentTo": -25},
         "reputation": {"establishedSpam": 25, "establishedHam": -15},
         "content": {"maximum": 30, "coldSolicitation": 45}, "provider": {"spamVerdict": 25},
         "blocklists": {"ipListed": 30, "ipDynamic": 12, "domainSpam": 30,
             "domainPhishOrMalware": 45, "domainAbusedLegit": 10, "urlMalware": 40},
         "domainAge": {"underWeek": 25, "underMonth": 15, "linkUnderWeek": 10},
         "impersonation": {"brandDisplayName": 18, "addressInDisplayName": 12,
             "lookalikeDomain": 30}}"""),
     MAX_CANDIDATE_TOKENS: int = 500,
     MAX_BAYESIAN_TOKENS: int = 20,
     TOKENIZER_VERSION: int = 1;
