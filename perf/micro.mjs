// Micro-benchmarks of the pure, compute-bound functions the Jac rewrite replaced.
// usage: node perf/micro.mjs <tree-root> [case...]   (tree-root: the original checkout, or
// the laid tree .jac/test/spaces/mailflare). Prints one JSON line per case:
// median ms per run over the runs, and a hash of its output to compare the two trees.
import { build } from "esbuild";
import { createHash } from "node:crypto";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = process.argv[2];
const only = process.argv.slice(3);
const dir = mkdtempSync(join(tmpdir(), "micro-"));
await build({
	stdin: {
		contents: `
			export { mimePreflightReason } from "./src/lib/email/mime-preflight";
			export { crc32, createZipStream, uniqueZipNames } from "./src/lib/zip";
			export { locateZipDirectory, inspectZipDirectory, assessAttachmentRisk } from "./src/lib/email/attachment-risk";
			export { isValidBase64 } from "./src/lib/email/base64";
			export { xmlTag, xmlTags, xmlBlocks } from "./src/lib/aws/xml";
			export { parseCsv, decodeContactsCsv, googleCsvMapper } from "./src/lib/contacts/google-csv";
			export { parseSearchQuery, buildFtsMatch } from "./src/lib/search/query-utils";
			export { isMissingTableError, isMissingColumnError, isUniqueConstraintError } from "./src/lib/database-errors";
			export { registrableDomain, isLookalikeDomain, extractSenderIp } from "./src/lib/spam/domain-utils";
			export { escapeXml, multistatus } from "./src/lib/dav/xml-writer";
			export { readSesTrace, readHeaderMap } from "./src/lib/email/provider-trace";
			export { CompatDatabase } from "./src/db/d1-compat";
			export { numberPlaceholders, normalizeParam } from "./src/db/drivers/types";
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

// Deterministic inputs.
let seed = 12345;
const rand = () => ((seed = (Math.imul(seed, 1103515245) + 12345) >>> 0) / 2 ** 32);
const enc = new TextEncoder();
const bytes = (n) => { const b = new Uint8Array(n); for (let i = 0; i < n; i++) b[i] = (rand() * 256) | 0; return b; };
const b64 = (b) => Buffer.from(b).toString("base64");
const wrap = (s, w = 76) => s.match(new RegExp(`.{1,${w}}`, "g")).join("\r\n");

const textPart = Array.from({ length: 3000 }, (_, i) => `Line ${i} of a plain text part with some words ${"x".repeat(i % 60)}`).join("\r\n");
const mime = enc.encode([
	"From: a@example.com", "To: b@example.com", "Subject: bench", "MIME-Version: 1.0",
	'Content-Type: multipart/mixed; boundary="b1"', "",
	"--b1", "Content-Type: text/plain; charset=utf-8", "", textPart,
	"--b1", "Content-Type: text/html; charset=utf-8", "", textPart,
	"--b1", "Content-Type: application/octet-stream", "Content-Transfer-Encoding: base64", "", wrap(b64(bytes(1_500_000))),
	"--b1", "Content-Type: message/rfc822", "", "Subject: inner", "", "inner body",
	"--b1--", "",
].join("\r\n"));
const blob = bytes(2_000_000);
const base64Text = b64(bytes(1_000_000));
const names = Array.from({ length: 2000 }, (_, i) => `folder/${["report", "Report", "photo", "a\\b"][i % 4]}${i % 50}.${["pdf", "PNG", "txt"][i % 3]}`);
const xml = `<?xml version="1.0"?><ListBucketResult>${Array.from({ length: 1500 }, (_, i) => `<Contents><Key>raw/${i}.eml</Key><Size>${i * 37}</Size><ETag>"e${i}"</ETag></Contents>`).join("")}<IsTruncated>false</IsTruncated></ListBucketResult>`;
const csv = ["Name,Given Name,Family Name,E-mail 1 - Value,Phone 1 - Value,Notes"].concat(Array.from({ length: 3000 }, (_, i) => `"Person ${i}",P${i},"Fam, ${i}",p${i}@example.com,+1555${i},"note ""${i}"" here"`)).join("\r\n");
const queries = Array.from({ length: 500 }, (_, i) => `from:alice@example.com subject:"report ${i}" has:attachment -is:read after:2024-01-${(i % 28) + 1} invoice OR receipt label:work${i}`);
const errors = Array.from({ length: 3000 }, (_, i) => i % 3 === 0 ? new Error("Failed query", { cause: new Error(`no such table: t${i}`) }) : i % 3 === 1 ? new Error(`SQLITE_ERROR: no such column: c${i}`) : { code: "23505", message: "duplicate key value violates unique constraint" });
const hosts = Array.from({ length: 2000 }, (_, i) => [`mail${i}.example.co.uk`, `paypa1-${i}.com`, `sub.domain${i}.github.io`, `x${i}.foo.com.au`][i % 4]);
const davResponses = Array.from({ length: 500 }, (_, i) => ({ href: `/dav/cal/${i}.ics?a=1&b=<x>`, propstats: [{ status: 200, props: [`<D:getetag>"${i}"</D:getetag>`] }, { status: 404, props: ["<C:missing/>"] }] }));
const sesRaw = enc.encode([
	"Return-Path: <x@example.com>", "Received: from mail.example.com (mail.example.com [203.0.113.5]) by inbound-smtp.us-east-1.amazonaws.com", 
	"X-SES-Spam-Verdict: PASS", "X-SES-Virus-Verdict: PASS",
	"Authentication-Results: amazonses.com; spf=pass (spfCheck: domain of example.com designates 203.0.113.5 as permitted sender) smtp.mailfrom=x@example.com; dkim=pass header.i=@example.com; dmarc=pass header.from=example.com;",
	...Array.from({ length: 200 }, (_, i) => `X-Header-${i}: value ${i}`),
	"Subject: hi", "", "body".repeat(1000),
].join("\r\n")).buffer;
const sqls = Array.from({ length: 2000 }, (_, i) => `SELECT * FROM messages WHERE mailbox_id = ? AND id > ? AND subject LIKE ? AND note = '?' LIMIT ${i}`);

async function zipBytes() {
	const stream = m.createZipStream([0, 1, 2].map((i) => ({ name: `f${i}.bin`, open: async () => new Response(blob.subarray(i * 500_000, (i + 1) * 500_000)).body })));
	const parts = []; for await (const c of stream) parts.push(c);
	return Buffer.concat(parts);
}
const zipped = await zipBytes();

const executor = { query: async (sql, params) => ({ rows: [{ sql, n: params.length }], affectedRows: 1, insertId: 1 }) };

const cases = {
	mimePreflight: () => m.mimePreflightReason(mime),
	crc32: () => m.crc32(blob),
	createZipStream: zipBytes,
	inspectZip: () => { const d = m.locateZipDirectory(zipped); return [d, m.inspectZipDirectory(zipped, (o, s) => zipped.subarray(o, o + s))]; },
	uniqueZipNames: () => m.uniqueZipNames(names),
	isValidBase64: () => m.isValidBase64(base64Text),
	xmlTags: () => [m.xmlTags(xml, "Key").length, m.xmlBlocks(xml, "Contents").length, m.xmlTag(xml, "IsTruncated")],
	parseCsv: () => { const { rows } = m.parseCsv(csv); const map = m.googleCsvMapper(rows[0]); return rows.slice(1).map(map); },
	parseSearchQuery: () => queries.map((q) => m.buildFtsMatch(m.parseSearchQuery(q))),
	databaseErrors: () => errors.map((e) => [m.isMissingTableError(e), m.isMissingColumnError(e), m.isUniqueConstraintError(e)]),
	domainUtils: () => hosts.map((h) => [m.registrableDomain(h), m.isLookalikeDomain(h, "paypal.com")]),
	davMultistatus: () => m.multistatus(davResponses),
	sesTrace: () => [m.readSesTrace(sesRaw), Object.keys(m.readHeaderMap(sesRaw)).length],
	d1Compat: async () => { const db = new m.CompatDatabase("postgres", executor); const out = []; for (const s of sqls) out.push(await db.prepare(s).bind(1, "x", true, null).all()); return out.length + JSON.stringify(out[5]); },
};

const ms = Number(process.env.MICRO_MS || 400);
for (const [name, fn] of Object.entries(cases)) {
	if (only.length && !only.includes(name)) continue;
	const out = await fn();
	const hash = createHash("sha256").update(JSON.stringify(out, (_k, v) => (v instanceof Uint8Array ? Buffer.from(v).toString("base64") : v)) ?? "undefined").digest("hex").slice(0, 12);
	const times = [];
	const until = performance.now() + ms;
	while (performance.now() < until || times.length < 5) { const t = performance.now(); await fn(); times.push(performance.now() - t); }
	times.sort((a, b) => a - b);
	console.log(JSON.stringify({ case: name, medianMs: +times[times.length >> 1].toFixed(3), runs: times.length, hash }));
}
