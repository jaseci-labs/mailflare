// Times the app's HTTP endpoints against a running server seeded with the demo data
// (POST /api/seed on a dev server, then `vp preview`).
// usage: node perf/endpoints.mjs <base-url> [runs]
// Prints one JSON line per endpoint: status, median ms, and a hash of the body with ids,
// numbers and hashed asset names masked, so two servers seeded apart can be compared.
import { createHash } from "node:crypto";

const base = process.argv[2];
const runs = Number(process.argv[3] || 30);

const login = await fetch(`${base}/api/auth/login`, {
	method: "POST",
	headers: { "content-type": "application/json" },
	body: JSON.stringify({ email: "admin@example.com", password: "demo-password-change-me" }),
});
const cookie = login.headers.getSetCookie().map((c) => c.split(";")[0]).join("; ");
if (!login.ok || !cookie) throw new Error(`login failed: ${login.status}`);
const get = (path) => fetch(base + path, { headers: { cookie }, redirect: "manual" });

const list = await (await get("/api/messages?status=received&limit=50")).json();
const first = list.messages[0];

const endpoints = [
	"/api/auth/me",
	"/api/messages?status=received&limit=50",
	"/api/messages?status=received&group=thread&limit=50",
	"/api/messages?q=invoice",
	"/api/messages?q=from%3Alumen%20has%3Aattachment",
	"/api/messages/counts",
	`/api/messages/${first.id}`,
	`/api/messages/${first.id}/thread`,
	"/api/mailboxes",
	`/api/contacts?mailboxId=${first.mailboxId}`,
	"/api/folders",
	"/inbox",
];

const mask = (text) =>
	text
		.replace(/<link rel="modulepreload"[^>]*>/g, "")
		.replace(/\b(msg|usr|mbx|att|sess|thr|fld|con|dom|ctc|key)_[A-Za-z0-9_-]+/g, "$1_#")
		.replace(/\/_next\/static\/[^"'\s]+/g, "asset")
		.replace(/[0-9a-f-]{6,}/g, "hex")
		.replace(/\d+/g, "#");

for (const path of endpoints) {
	let status = 0;
	let body = "";
	for (let i = 0; i < 3; i++) {
		const r = await get(path);
		status = r.status;
		body = await r.text();
	}
	const times = [];
	for (let i = 0; i < runs; i++) {
		const t = performance.now();
		const r = await get(path);
		await r.arrayBuffer();
		times.push(performance.now() - t);
	}
	times.sort((a, b) => a - b);
	const hash = createHash("sha256").update(mask(body)).digest("hex").slice(0, 12);
	console.log(JSON.stringify({ path: path.replace(/(msg|mbx)_[A-Za-z0-9_-]+/g, "$1_#"), status, medianMs: +times[runs >> 1].toFixed(2), bytes: body.length, hash }));
}
