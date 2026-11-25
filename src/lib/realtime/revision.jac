glob:priv REVISIONS_SQL: str = """
		SELECT m.id AS mailbox_id, COALESCE(r.revision, 0) AS revision, 'owner' AS permission
		FROM mailboxes m
		LEFT JOIN jmap_mailbox_revisions r ON r.mailbox_id = m.id
		WHERE m.user_id = ? AND NOT m.disabled
		UNION
		SELECT m.id AS mailbox_id, COALESCE(r.revision, 0) AS revision, a.permission AS permission
		FROM mailbox_access a
		JOIN mailboxes m ON m.id = a.mailbox_id
		LEFT JOIN jmap_mailbox_revisions r ON r.mailbox_id = m.id
		WHERE a.user_id = ? AND m.type = 'shared' AND NOT m.disabled
		ORDER BY mailbox_id, permission
	""";

"""Covers every mailbox visible to a user, including shared mailboxes."""
async def getUserMailRevision(env: any, userId: any) -> str {
    result = await env.DB.prepare(REVISIONS_SQL).bind(userId, userId).all();
    return globalThis.JSON.stringify([
        [row["mailbox_id"], row["revision"], row["permission"]]
        for row in result.results
    ]);
}
