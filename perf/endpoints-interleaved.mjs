// Times the same endpoints on several running servers at once, one request to each in turn
// (rotating who goes first), so load swings on a shared machine fall on all of them alike.
// usage: node perf/endpoints-interleaved.mjs <runs> <label>=<base-url> ...
const runs = Number(process.argv[2]);
const servers = process.argv.slice(3).map((a) => ({ label: a.split("=")[0], base: a.slice(a.indexOf("=") + 1) }));
for (const s of servers) {
	const login = await fetch(`${s.base}/api/auth/login`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email: "admin@example.com", password: "demo-password-change-me" }) });
	s.cookie = login.headers.getSetCookie().map((c) => c.split(";")[0]).join("; ");
	s.get = (path) => fetch(s.base + path, { headers: { cookie: s.cookie }, redirect: "manual" });
	const list = await (await s.get("/api/messages?status=received&limit=50")).json();
	s.first = list.messages[0];
}
const paths = [
	() => "/api/auth/me",
	() => "/api/messages?status=received&limit=50",
	() => "/api/messages?status=received&group=thread&limit=50",
	() => "/api/messages?q=invoice",
	() => "/api/messages?q=from%3Alumen%20has%3Aattachment",
	() => "/api/messages/counts",
	(s) => `/api/messages/${s.first.id}`,
	(s) => `/api/messages/${s.first.id}/thread`,
	() => "/api/mailboxes",
	(s) => `/api/contacts?mailboxId=${s.first.mailboxId}`,
	() => "/api/folders",
	() => "/inbox",
];
for (const path of paths) {
	for (const s of servers) for (let i = 0; i < 3; i++) await (await s.get(path(s))).arrayBuffer();
	const times = Object.fromEntries(servers.map((s) => [s.label, []]));
	for (let i = 0; i < runs; i++) {
		for (let k = 0; k < servers.length; k++) {
			const s = servers[(i + k) % servers.length];
			const t = performance.now();
			await (await s.get(path(s))).arrayBuffer();
			times[s.label].push(performance.now() - t);
		}
	}
	const med = (xs) => xs.sort((a, b) => a - b)[xs.length >> 1];
	console.log(JSON.stringify({ path: path(servers[0]).replace(/(msg|mbx)_[A-Za-z0-9_-]+/g, "$1_#"), ...Object.fromEntries(servers.map((s) => [s.label, +med(times[s.label]).toFixed(1)])) }));
}
