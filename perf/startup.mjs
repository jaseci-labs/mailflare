// Start-up of one module as the tests load it: esbuild-bundle it from a tree root, then import it.
// usage: node perf/startup.mjs <tree-root> <module path without extension>
import { build } from "esbuild";
import { mkdtempSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
const [root, mod] = process.argv.slice(2);
const dir = mkdtempSync(join(tmpdir(), "su-"));
const t0 = performance.now();
await build({ stdin: { contents: `export * from "./${mod}";`, resolveDir: root, loader: "ts" }, outfile: join(dir, "m.mjs"), bundle: true, platform: "node", format: "esm", logLevel: "silent", alias: { "@": join(root, "src") } });
const t1 = performance.now();
const m = await import(pathToFileURL(join(dir, "m.mjs")).href);
const t2 = performance.now();
console.log(JSON.stringify({ mod, bundleMs: +(t1 - t0).toFixed(1), importMs: +(t2 - t1).toFixed(1), bytes: statSync(join(dir, "m.mjs")).size, exports: Object.keys(m).length }));
