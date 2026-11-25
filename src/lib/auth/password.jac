import from "bcryptjs" { default as bcrypt }

"""Passkey-only accounts still need a non-null column (SQLite cannot drop NOT NULL cheaply). hashPassword
never produces this sentinel and every verification path rejects it, like a missing password."""
glob PASSWORDLESS_PASSWORD_HASH: str = "!passkey-only";

def hashPassword(password: any) -> any {
    return bcrypt.hashSync(password, 12);
}

def hasPasswordHash(stored: any = None) -> bool {
    return bool(stored) and stored != PASSWORDLESS_PASSWORD_HASH and stored.startsWith("$2");
}

def verifyPassword(password: any, stored: any = None) -> bool {
    return hasPasswordHash(stored) and bcrypt.compareSync(password, stored);
}
