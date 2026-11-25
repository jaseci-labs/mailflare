import from "bcryptjs" { default as bcrypt }

"""Accounts that sign in only with passkeys still need a non-null column value: SQLite cannot drop
`NOT NULL` without rebuilding a heavily referenced table. The sentinel can never be produced by
hashPassword and every verification path rejects it, so it behaves like a missing password."""
glob PASSWORDLESS_PASSWORD_HASH: str = "!passkey-only";

def hashPassword(password: any) -> str {
    return bcrypt.hashSync(password, 12);
}

def hasPasswordHash(stored: any = None) -> bool {
    return bool(stored) and stored != PASSWORDLESS_PASSWORD_HASH and stored.startsWith("$2");
}

def verifyPassword(password: any, stored: any = None) -> bool {
    return hasPasswordHash(stored) and bcrypt.compareSync(password, stored);
}
