import from "drizzle-orm" { and as all_of, count, eq, inArray }

"""How many messages of the mailbox were marked `classification`."""
async def:priv trained(db: any, mailboxId: str, classification: str) -> int {
    rows = await db.select({"value": count()}).from(spamFeedback).where(
        all_of(
            eq(spamFeedback.mailboxId, mailboxId), eq(spamFeedback.classification, classification)
        ),
    );
    return at(rows[0], "value", 0) if rows.length else 0;
}

"""Naive Bayes over the mailbox's token counts: the 20 most telling tokens decide, scaled by how much was trained."""
async def classifyTokens(db: any, mailboxId: str, tokens: any) -> dict[str, any] {
    found = await globalThis.Promise.all([
        trained(db, mailboxId, "spam"),
        trained(db, mailboxId, "ham"),
    ]);
    (spam_total, ham_total) = found;
    untrained = {
        "probability": 0.5,
        "contribution": 0,
        "trainedMessages": spam_total + ham_total,
        "strongestTokens": [],
    };
    if spam_total == 0 or ham_total == 0 or len(tokens) == 0 {
        return untrained;
    }
    scored: list[any] = [];
    # D1 allows 100 bound parameters per statement.
    for index in range(0, len(tokens), 90) {
        rows = await db.select().from(spamTokenStats).where(
            all_of(
                eq(spamTokenStats.mailboxId, mailboxId),
                inArray(spamTokenStats.token, tokens[index:index + 90]),
            ),
        );
        for row in rows {
            spam_rate = (row.spamCount + 1) / (spam_total + 2);
            ham_rate = (row.hamCount + 1) / (ham_total + 2);
            scored.append({
                "token": row.token,
                "probability": max(0.1, min(0.9, spam_rate / (spam_rate + ham_rate))),
            });
        }
    }
    if not scored {
        return untrained;
    }
    strongest = sorted(
        scored, key=lambda (item: any) -> any { -abs(item["probability"] - 0.5) }
    )[:MAX_BAYESIAN_TOKENS];
    (spam_product, ham_product) = (1.0, 1.0);
    for item in strongest {
        spam_product *= item["probability"];
        ham_product *= 1 - item["probability"];
    }
    probability = spam_product / (spam_product + ham_product);
    reliability = min(1, min(spam_total, ham_total) / 20);
    return {
        "probability": probability,
        "contribution": globalThis.Math.round(
            (probability - 0.5) * SPAM_WEIGHTS.content.maximum * 2 * reliability
        ),
        "trainedMessages": spam_total + ham_total,
        "strongestTokens": strongest,
    };
}
