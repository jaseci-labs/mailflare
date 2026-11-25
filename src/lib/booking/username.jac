import from "drizzle-orm" { and as both, eq, isNull }

"""The user's stored booking username, as a one-row query."""
def:priv stored(db: any, userId: str) -> any {
    return db.select(record({"bookingUsername": users.bookingUsername})).from(users).where(
        eq(users.id, userId)
    ).limit(1);
}

def:priv name_of(rows: any) -> any {
    return rows[0].bookingUsername if rows.length else None;
}

"""The user's booking username, assigning the first free one made from their address when they have none."""
async def ensureBookingUsername(env: any, userId: str, email: str) -> str {
    db = getDb(env);
    current = await stored(db, userId);
    if not current.length {
        raise new(globalThis.Error, "User not found");
    }
    if name_of(current) {
        return name_of(current);
    }
    base = bookingUsernameFromEmail(email);
    for number in range(1, 100000) {
        candidate = base if number == 1 else f"{base}{number}";
        taken = await db.select(record({"id": users.id})).from(users).where(
            eq(users.bookingUsername, candidate)
        ).limit(1);
        if taken.length {
            continue;
        }
        try {
            # Only an account still without a username takes it, so two requests cannot both assign one.
            updated = await db.update(users).set(record({"bookingUsername": candidate})).where(
                both(eq(users.id, userId), isNull(users.bookingUsername))
            ).returning(record({"bookingUsername": users.bookingUsername}));
            assigned = name_of(updated) or name_of(await stored(db, userId));
            if assigned {
                return assigned;
            }
        } except Exception as error {
            if isUniqueConstraintError(error) {
                continue;
            }
            raise;
        }
    }
    raise new(globalThis.Error, "Could not assign a booking username");
}
