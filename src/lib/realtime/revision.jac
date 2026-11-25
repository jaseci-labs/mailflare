"""Covers every mailbox visible to a user, including shared mailboxes."""
async def getUserMailRevision(env: any, userId: any) -> str {
    result = await env.DB.prepare("""
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
	""").bind(userId, userId).all();
    rows = [[r["mailbox_id"], r["revision"], r["permission"]] for r in result.results];
    return globalThis.JSON.stringify(rows);
}
