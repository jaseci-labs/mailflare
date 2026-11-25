// Micro-benchmarks, second set: the browser's message-list stores, date formatting, calendar
// expansion, JMAP ids and AWS request signing. Same usage and output as perf/micro.mjs.
import { build } from "esbuild";
import { createHash } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = process.argv[2];
const only = process.argv.slice(3);
const dir = mkdtempSync(join(tmpdir(), "micro2-"));
await build({
	stdin: {
		contents: `
			export { rememberMessageRows, applyPendingToMessageList, setPendingOverlay, clearPendingOverlay, clearKnownMessageFieldsForTests } from "./src/lib/messages/field-store";
			export { rememberMembershipRows, applyMembershipToList, setMembershipOverlay, clearMembershipOverlay, clearMembershipForTests } from "./src/lib/messages/membership-store";
			export { formatUserDate, zonedDateFields, dateFromZonedFields } from "./src/lib/time/utils";
			export { expandToolEvents } from "./src/lib/calendar/tool-occurrences";
			export { encodeMailboxRef, decodeMailboxRef, decodeBlobId, identityId, decodeIdentityId } from "./src/lib/jmap/ids";
			export { signAwsRequest } from "./src/lib/aws/sigv4";
		`,
		resolveDir: root,
		loader: "ts",
	},
	outfile: join(dir, "m.mjs"),
	bundle: true,
	platform: "node",
	format: "esm",
	logLevel: "silent",
	alias: { "@": join(root, "src") },
});
const m = await import(pathToFileURL(join(dir, "m.mjs")).href);
rmSync(dir, { recursive: true, force: true });

const row = (i) => ({
	id: `msg_${i}`, userId: "usr_1", mailboxId: `mbx_${i % 3}`, direction: "inbound", status: i % 7 === 0 ? "archived" : "received",
	read: i % 2 === 0, starred: i % 5 === 0, folderId: null, snoozedUntil: null, threadId: `thr_${i % 20}`, category: null,
	subject: `Subject ${i}`, fromAddr: `a${i}@example.com`, createdAt: 1_700_000_000_000 + i * 60_000, threadCount: 1 + (i % 3), threadUnread: i % 2,
});
const rows = Array.from({ length: 50 }, (_, i) => row(i));
const listResponse = { messages: rows, total: 500, offset: 0 };
const dates = Array.from({ length: 300 }, (_, i) => new Date(Date.UTC(2025, i % 12, 1 + (i % 28), i % 24, i % 60)));
const zones = ["UTC", "America/New_York", "Europe/Berlin", "Asia/Tokyo", "Australia/Sydney"];
const events = Array.from({ length: 20 }, (_, i) => ({
	id: `evt_${i}`, title: `Event ${i}`, description: "", location: "", attendees: JSON.stringify([`p${i}@example.com`]), color: "blue",
	repeat: ["daily", "weekly", "monthly", "yearly", "weekdays", "none"][i % 6], repeatInterval: 1 + (i % 2), repeatDays: "1,2,3,4,5",
	repeatWeekday: null, repeatWeek: null, repeatAnchorDay: null, repeatUntil: null, excludedOccurrences: null,
	timeZone: zones[i % zones.length], startsAt: new Date(Date.UTC(2025, 0, 1 + i, 9)), endsAt: new Date(Date.UTC(2025, 0, 1 + i, 10)),
}));
const credentials = { accessKeyId: "AKIDEXAMPLE", secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY" };

const cases = {
	messageListStores: () => {
		m.clearKnownMessageFieldsForTests();
		m.clearMembershipForTests();
		m.rememberMessageRows(rows);
		m.rememberMembershipRows(rows);
		m.setPendingOverlay("owner", rows.slice(0, 10).map((r) => ({ id: r.id, fields: { read: !r.read } })));
		const out = [];
		for (let k = 0; k < 20; k++) out.push(m.applyMembershipToList(m.applyPendingToMessageList(listResponse), "inbox"));
		m.clearPendingOverlay("owner");
		return out[19];
	},
	formatDates: () => dates.map((d, i) => [m.formatUserDate(d, { timeZone: zones[i % 5], dateStyle: "medium", timeStyle: "short" }), m.dateFromZonedFields(m.zonedDateFields(d, zones[i % 5]), zones[i % 5]).toISOString()]),
	expandEvents: () => m.expandToolEvents(events, new Date(Date.UTC(2025, 2, 1)), new Date(Date.UTC(2025, 5, 1)), 2000),
	jmapIds: () => {
		const out = [];
		for (let i = 0; i < 3000; i++) {
			const ref = m.encodeMailboxRef(i % 3 === 0 ? { kind: "account", mailboxId: `mbx_${i}` } : i % 3 === 1 ? { kind: "role", mailboxId: `mbx_${i}`, role: "inbox" } : { kind: "folder", mailboxId: `mbx_${i}`, folderId: `fld_${i}` });
			out.push(m.decodeMailboxRef(ref), m.decodeBlobId(`att~${i}`), m.decodeIdentityId(m.identityId(`mbx_${i}`, `a${i}@example.com`)));
		}
		return out;
	},
	sigv4: async () => {
		const out = [];
		for (let i = 0; i < 100; i++) out.push(await m.signAwsRequest({ method: "PUT", url: new URL(`https://bucket.s3.us-east-1.amazonaws.com/raw/${i}.eml?x-id=PutObject`), region: "us-east-1", service: "s3", credentials, headers: { "content-type": "message/rfc822" }, body: `body ${i}`, now: new Date(Date.UTC(2025, 0, 1)) }));
		return out;
	},
};

const ms = Number(process.env.MICRO_MS || 400);
for (const [name, fn] of Object.entries(cases)) {
	if (only.length && !only.includes(name)) continue;
	let out;
	try { out = await fn(); } catch (error) { console.log(JSON.stringify({ case: name, error: String(error) })); continue; }
	const hash = createHash("sha256").update(JSON.stringify(out, (_k, v) => (v instanceof Map ? [...v] : v)) ?? "undefined").digest("hex").slice(0, 12);
	const times = [];
	const until = performance.now() + ms;
	while (performance.now() < until || times.length < 5) { const t = performance.now(); await fn(); times.push(performance.now() - t); }
	times.sort((a, b) => a - b);
	console.log(JSON.stringify({ case: name, medianMs: +times[times.length >> 1].toFixed(3), runs: times.length, hash }));
}
