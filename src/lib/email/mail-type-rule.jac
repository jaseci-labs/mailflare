# The only `mail_type` value so far: newsletters, promotions and mailing-list mail (see `isBulkMail`).
glob MAIL_TYPE_BULK: str = "bulk";

# Error code the rule API returns when a `mail_type` rule would lose mail (reject, or forward
# without keeping a copy). The UI translates it; the code itself is an API value.
glob MAIL_TYPE_UNSAFE_ACTION: str = "mail_type_unsafe_action";

"""The message to show for a failed rule request.

The API answers with a plain string or a flattened validation error; the unsafe-action code is
kept as is so the caller can translate it.
"""
def ruleErrorMessage(error: any, fallback: str) -> str {
    if isinstance(error, str) {
        return error;
    }
    fields = None if nil(error) else getattr(error, "fieldErrors", None);
    unsafe = fields
        and globalThis.Object.values(fields).some(
            lambda (messages: any) -> any {
                not nil(messages) and messages.includes(MAIL_TYPE_UNSAFE_ACTION)
            },
        );
    return MAIL_TYPE_UNSAFE_ACTION if unsafe else fallback;
}
