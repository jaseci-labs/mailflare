# MAIL_TYPE_BULK, the only `mail_type` value so far: newsletters, promotions and mailing-list mail
# (see `isBulkMail`). MAIL_TYPE_UNSAFE_ACTION: the error code the rule API returns when a
# `mail_type` rule would lose mail (reject, or forward without keeping a copy); the UI translates it.
glob MAIL_TYPE_BULK: str = "bulk",
     MAIL_TYPE_UNSAFE_ACTION: str = "mail_type_unsafe_action";

# The message for a failed rule request: the API answers with a plain string or a flattened
# validation error, whose unsafe-action code is kept as is so the caller can translate it.
def ruleErrorMessage(error: any, fallback: str) -> str {
    if isinstance(error, str) {
        return error;
    }
    fields = dig(error, ["fieldErrors"]);
    lists = globalThis.Object.values(fields) if fields else [];
    unsafe = any(not nil(m) and m.includes(MAIL_TYPE_UNSAFE_ACTION) for m in lists);
    return MAIL_TYPE_UNSAFE_ACTION if unsafe else fallback;
}
