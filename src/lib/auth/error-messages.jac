# code=key pairs, read into a plain object so `in` sees it as the original did.
glob:priv PAIRS: str = """rate_limited=rateLimited passkey_unavailable=passkeyUnavailable
    passkey_expired=passkeyExpired passkey_invalid=passkeyInvalid passkey_not_found=passkeyNotFound
    passkey_already_registered=passkeyAlreadyRegistered passkey_disabled=accountDisabled
    passkey_counter_stale=passkeyInvalid passkey_origin=passkeyOrigin setup_invalid=setupInvalid
    session_expired=sessionExpired verification_required=verificationRequired last_method=lastMethod
    verification_failed=verificationFailed passkey_only_password=passkeyOnlyPassword
    account_disabled=accountDisabled passkey_cancelled=passkeyCancelled code_mismatch=codeMismatch
    invalid_credentials=invalidCredentials password_incorrect=passwordIncorrect
    invalid_request=invalidRequest action_conflict=actionConflict
    recovery_cleanup_failed=recoveryCleanupFailed""",
          KEYS: any = record({
              kv[0]: f"authError.{kv[1]}"
              for kv in [p.split("=") for p in PAIRS.split()]
          });

"""Translate a server error code, falling back to a call-site key."""
def authErrorText(code: any, t: any, fallbackKey: any) -> any {
    known = isinstance(code, str) and globalThis.Reflect.has(KEYS, code);
    return t(KEYS[code] if known else fallbackKey);
}
