glob:priv TLS = "REPORTS_REQUIRED MULTIPLE_TLSRPT_RECORDS DNS_FAILED MIGRATION_REQUIRED".split(),
          MTA_STS = """NO_MX TOO_MANY_MX MTA_STS_RECORD_EXISTS MULTIPLE_MTA_STS_RECORDS TESTING_FIRST
              ACKNOWLEDGE_REQUIRED INVALID_MX MX_CHANGED_IN_ENFORCE NOT_PUBLISHED INVALID_MAX_AGE
              DNS_FAILED MIGRATION_REQUIRED""".split(),
          POLICIES = ["sts", "tlsa", "no-policy-found"],
          DRIFT = ["mxDrift", "differs"];

# Line by line, ignoring line endings and trailing blank lines, so a CRLF-rewriting proxy matches.
def:priv norm(text: any) -> str {
    rows = sub(text, rx(r"\r\n", "g"), "\n").trimEnd().split("\n");
    return "\n".join([row.trimEnd() for row in rows]);
}

# MAX_AGE_OPTIONS: the cache times the server accepts: a day, a week, 30 days, a year. mxDiffers:
# the policy lists other MX hosts than the domain has now; false when off or DNS was unreadable.
glob MAX_AGE_OPTIONS: any = [86_400, 604_800, 2_592_000, 31_557_600],
     retiringDays: any = lambda (maxAge: any) -> any { globalThis.Math.ceil(maxAge / 86_400) },
     tlsErrorKey: any = lambda (code: any) -> any { f"tls.error.{code}" if code in TLS else NULL },
     mtaStsErrorKey: any = lambda (c: any) -> any { f"mtasts.error.{c}" if c in MTA_STS else NULL },
     policyKey: any = lambda (t: any) -> any { f"tls.policy.{t}" if t in POLICIES else NULL },
     policyMatches: any = lambda (a: any, b: any) -> any { b.trim() != "" and norm(a) == norm(b) },
     mxDiffers: any = lambda (d: any) -> any { d.status != "off" and bool(dig(d, DRIFT)) };
