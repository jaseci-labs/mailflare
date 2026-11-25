# Performance of the Jac rewrite

The original TypeScript (`base/mailflare`, commit 772753d3c) was measured against the Jac rewrite before this
work (`neojac-deslop`, 8d68313) and after it (`neojac-perf`). The machine is a shared 20-core Linux box,
and other users kept the load average between 6 and 50 throughout. Runs were therefore alternated,
original → Jac before → Jac after, in each of 3 rounds (`perf/compare.sh`), and every figure below is
a median. During the final runs the load average was 10.0–14.6, median 12.2. All three trees use
the same `node_modules` contents and neojac's Node v26.13.0.

## Where the code runs

`archwire.jac` has one space, `space mailflare: node { "."; }`. All 201 Jac modules are compiled to
JavaScript and run in V8 on three hosts:

- in the Cloudflare Worker (workerd), next to the TypeScript that imports them;
- in Node, for the tests and the self-hosted build;
- in the browser, for the client components' `*-utils` modules.

Nothing runs on CPython. No native space can serve this code (blocker 1 below). The only levers
were therefore the JavaScript the Jac emits and how much of it loads.

## Results

### Whole workloads

| workload | original | Jac before | Jac after |
|---|---|---|---|
| test suite (`node --test tests/*.test.mjs`, 2138 tests), wall s | 42.3 | 52.3 | 51.6 |
| test suite, CPU s (user+sys) | 527 | 565 | 564 |
| `npm run build` (vinext, full Worker), wall s | 29.1 | 31.8 | 31.9 |
| server cold start (`vp preview` launch to first answer), s | 2.63 | 3.48 | 3.51 |
| start-up: `src/lib/ids` bundled and imported as a test does, ms | 9.1 | 84.9 | 72.5 |
| ... its bundle size, KB | 1 | 790 | 823 |
| Worker JS (`dist/server`), bytes | 9,287,293 | 10,065,691 | 10,113,271 |
| browser JS (`dist/client`), bytes / gzipped | 3,135,177 / 842,976 | 3,534,382 / 962,367 | 3,551,911 / 968,479 |

- **Tests:** every tree ran all 2138 tests. 2135 pass, 2 are skipped, and 1 fails on all three: "quoted-printable
  soft breaks join in one pass and stay bounded", a timing bound the loaded machine breaks for the
  original too.
- **Lay overhead:** the Jac figures do not include neojac's laying of the tree. That adds ~3 s to every
  `neojac npm run ...` when warm, and ~135 s the first time after neojac's cache is cold. For example,
  a cold `neojac test` took 199 s, of which the suite was 64 s.

### Server endpoints

The original, Jac-before and Jac-after builds were served with `vp preview` (local workerd and D1),
each seeded with the demo data. All three were up at once, and each endpoint was requested 60 times
per server, round-robin (`perf/endpoints-interleaved.mjs`). Load average was 6–7.

| endpoint, median ms | original | Jac before | Jac after |
|---|---|---|---|
| `/api/auth/me` | 28.4 | 28.0 | 26.7 |
| `/api/messages?status=received&limit=50` | 65.3 | 65.4 | 66.0 |
| `/api/messages?…&group=thread` | 55.1 | 54.9 | 55.0 |
| `/api/messages?q=invoice` | 49.2 | 47.7 | 48.1 |
| `/api/messages?q=from:lumen has:attachment` | 46.0 | 46.1 | 45.9 |
| `/api/messages/counts` | 38.7 | 36.7 | 36.1 |
| `/api/messages/<id>` | 43.9 | 45.0 | 45.8 |
| `/api/messages/<id>/thread` | 52.3 | 52.4 | 52.1 |
| `/api/mailboxes` | 99.6 | 100.3 | 99.5 |
| `/api/contacts?mailboxId=…` | 34.4 | 34.0 | 35.0 |
| `/api/folders` | 28.5 | 28.9 | 28.5 |
| `/inbox` (SSR page) | 61.1 | 62.8 | 62.5 |

- **Request time:** it is dominated by local D1 and workerd, so the trees cannot be told apart here.
- **Same responses:** every endpoint gives the same status and body on all three, once ids, numbers and
  build hashes are masked (`perf/endpoints.mjs`). One exception is the Jac-before snapshot's `/inbox`:
  copying that tree to `/tmp` left absolute font paths in its build, which is not a Jac difference.

### The Jac code's own work

These are the functions the rewrite replaced, called on the same inputs in each tree
(`perf/micro.mjs`, `perf/micro2.mjs`). Each figure is the median ms per call, with the median taken
over 3 rounds. "Same output" means a hash of the result equals the original's.

| case | original | Jac before | Jac after | after vs before | after vs original | same output |
|---|---|---|---|---|---|---|
| D1-compat: 2000 prepared PostgreSQL statements | 2.08 | 441.2 | 36.0 | 12.3x faster | 17x | yes |
| crc32, 2 MB | 4.86 | 513.7 | 64.3* | 8.0x | 13x | yes |
| createZipStream, 1.5 MB | 4.18 | 367.1 | 19.3 | 19.0x | 4.6x | yes |
| mimePreflight, 4 MB mail (every inbound message) | 1.77 | 36.2 | 3.34 | 10.8x | 1.9x | yes |
| inspectZip | 0.003 | 0.054 | 0.019 | 2.8x | 6.3x | yes |
| uniqueZipNames, 2000 names | 2.03 | 13.8 | 3.90 | 3.6x | 1.9x | yes |
| sesTrace | 0.085 | 1.24 | 0.161 | 7.7x | 1.9x | yes |
| xmlTags (S3 listing) | 0.66 | 15.2 | 0.94 | 16.2x | 1.4x | yes |
| davMultistatus, 500 responses | 0.50 | 8.81 | 0.81 | 10.9x | 1.6x | yes |
| parseCsv, 3000 contacts | 11.5 | 193.3 | 40.0 | 4.8x | 3.5x | yes |
| parseSearchQuery, 500 queries | 14.7 | 110.3 | 22.0 | 5.0x | 1.5x | yes |
| databaseErrors, 9000 checks | 0.93 | 32.0 | 7.43 | 4.3x | 8.0x | yes |
| domainUtils (spam), 2000 hosts | 13.1 | 50.9 | 10.2 | 5.0x | **0.8x** | yes |
| message-list stores (browser, per render) | 0.028 | 3.73 | 0.071 | 52.5x | 2.5x | yes |
| formatDates, 300 dates | 8.64 | 49.0 | 11.1 | 4.4x | 1.3x | yes |
| expandEvents (calendar recurrence) | 20.9 | 118.8 | 27.1 | 4.4x | 1.3x | yes |
| jmapIds, 3000 rounds | 1.23 | 18.3 | 12.8 | 1.4x | 10.5x | yes |
| sigv4, 100 signatures | 18.4 | 43.6 | 10.3 | 4.2x | **0.6x** | yes |
| isValidBase64 (already a single regex) | 5.77 | 5.77 | 5.76 | 1.0x | 1.0x | yes |

\* crc32 measured 22.8 ms in quieter runs while it was being worked on. It is the most load-sensitive case.

The agents also measured these cases with their own benchmarks, in one session each:

| case | original | Jac before | Jac after |
|---|---|---|---|
| `splitMboxBytes`, 4 MB mbox import | 137 | 924 | **106** |
| spam `findHeader`, 3 lookups x 500 messages | 1.39 | 15.1 | 3.3 |
| spam authentication analysis x 500 | 2.2 | 22.9 | 4.2 |
| `extractSenderIp` x 500 | 0.98 | 8.4 | 2.3 |
| origin checks x 500 requests | 0.50 | 3.54 | 1.9 |
| calendar subscription feed, 200 events | 32 | 46 | **7.2** |
| JMAP `coalesceChanges`, 5000 rows | 0.24 | 5.2 | 1.0 |

The faster-than-original results come from caching. The feed keeps one `Intl.DateTimeFormat` per
zone, which the original built per date, and SigV4 keeps derived signing keys, as the AWS SDKs do.
The mbox import gets a one-call encode for 7-bit messages. Output is unchanged in all three.

## What made the difference

Nothing could move to a native space, so the gains are all in what the Jac compiles to on a
JavaScript host. Reading the emitted `.jac/test/spaces/mailflare/.jac/**/*.mjs` and profiling with
`--cpu-prof` showed the same few costs everywhere.

1. **Tuple assignment.**
   - What it compiles to: `(a, b) = (x, y)` becomes `$j.unpack($j.tup(x, y), 2)`.
   - Cost: an array subclass built and taken apart. It was 37% of the D1-compat profile and about
     half of the message-store profile (with `zip`).
   - Fix: separate assignments.
2. **Per-character and per-byte Jac loops.**
   - Cost: every subscript is `$j.getitem`, every untyped `.m()` is `$j.callattr`, and every operator on `any` is
     `$j.dyn`.
   - Fix: hand the scan to one JS builtin and loop in Jac per piece. `numberPlaceholders` is one regex
     `split`, and the CSV, XML, search, header and DAV code went the same way. Where bytes must be
     visited (CRC-32, the MIME scan), read them with
     `globalThis.DataView.prototype.getInt32.call(...)` / `globalThis.Reflect.get(...)`, which compile
     to direct calls. Use typed `int` locals and table lookups from `list[int]` (`$j.at`).
3. **Closures built per call.**
   - Cost: a lambda or nested `def` handed to JavaScript (a callback, `.then`, a `replace` function)
     gets a JavaScript face built on every call (`js_fn`, `dressed`, `defineProperty`).
   - Fix: hoist them, or replace callbacks with loops. D1-compat also stopped building a `Proxy` per
     statement and shares one.
4. **Regexes and constant tables built per call.** `rx(...)` builds a new `RegExp` each time, and the
   stores re-split string tables. Fix: module-level globs.
5. **The `def` boundary.**
   - Cost: a TypeScript call into a Jac `def` goes through its face, which copies the arguments and
     converts the result, about 0.4–0.5 µs per call.
   - Fix: the message-list stores export their hot entry points as `glob` lambdas (the pattern
     `captureVisibleMembership` already used), which skips it. Elsewhere this cost is what remains in
     `jmapIds` and `databaseErrors`.
6. **Copies at JS calls.** `$j.plain` copies any array not marked as JavaScript's own on every direct call.
   Fix: iterate with `for x in xs` rather than `Reflect.get(xs, i)` in a loop, which had made `sesTrace`
   and `formatToParts` quadratic.

Start-up did not improve. Whatever the code does, every test, the Worker and the browser load
all 198 emitted modules and the 93 KB runtime (blocker 2). The rewrites added about 4% to that
emitted code (790 → 823 KB), because the hot paths are now written out in full. The test suite,
build and cold start are therefore as before: 10–25% slower than the original.

### Behaviour

- **Checks:** every change was checked against the original TypeScript, bundled from `base/mailflare`, by a
  randomized differential fuzzer (thousands to hundreds of thousands of calls per module), as well as by the
  tests and the output hashes above.
- **Old port bugs fixed:** the fuzzers found places where the old port differed from the original. Each now
  matches the original:
  - `roleToStatus`/`statusToRole` raised on non-string input;
  - `encodeMailboxRef` raised on a null `mailboxId`;
  - the message stores raised `TypeError: expected bool, found JsNull` on a null `starred`;
  - `expandToolEvents` was a reinterpretation of the original rather than a port.
- **Known differences left, both present before this work:**
  - `assessAttachmentRisk` with a non-string `type` returns where the original throws;
  - the message stores' row copies (`Object.assign`, previously `merged()`) drop an own `__proto__`
    key that object spread keeps.

## Where neojac blocks a speed-up

Each has a minimal reproduction: a project made of the files shown, with neojac 0.5.1
(`neojac 0.5.1 (linux-x86_64, 060988d8fbd5)`). The `jac.toml` of every one is:

```toml
[project]

[npm."."]
name = "repro"
version = "0.0.0"
private = true
type = "module"
scripts = { test = "node --test tests/*.test.mjs", t = "node --test" }

[test.npm."."]
script = "test"
```

### 1. No native space can serve this app's code

The Jac runs inside a Cloudflare Worker (and in Node for tests and the self-hosted build), and
TypeScript calls it synchronously. A native space cannot be reached from there:

- A TypeScript file cannot import a Jac module of another space at all:

  ```jac
  # archwire.jac
  graph layers { layer all { *; } }
  graph spaces {
      space web: node { "."; }
      space fast: native { calc; }
  }
  graph import {
      calc --> lib.use { double }
      lib.use --> "tests/use.test" { quad }
  }
  ```
  ```jac
  # calc.jac
  def:pub double(x: int) -> int { return x * 2; }
  ```
  ```ts
  // lib/use.ts
  import { double } from "../calc.js";
  export function quad(x: number): number { return double(double(x)); }
  ```
  `neojac check`:
  ```text
  lib/use.ts:1:1: error[E5090]: neojac does not support a JavaScript file importing the Jac module 'calc' outside a JS space they share yet
  ```

- Through a Jac module of the node space, the call is a crossing, which is an HTTP request to a
  running native server and is asynchronous, so every synchronous helper would become a promise
  (and a Worker has no native process to call):

  ```jac
  # archwire.jac: as above, with
  #     calc ++> bridge { double }
  #     bridge --> lib.use { quad }
  # bridge.jac (node space)
  def:pub quad(x: int) -> int { return double(double(x)); }
  ```
  ```text
  bridge.jac:2:12: error[E1002]: cannot return Coroutine[any, any, int] from a function declared to return int
  bridge.jac:2:19: error[E1053]: double()'s parameter 'x' expects int, found Coroutine[any, any, int]
  ```
  The same holds for a `wasm` space. So everything stays in the one `node` space, where Jac is
  JavaScript run by V8, and the only levers are the emitted JavaScript and how much of it loads.

### 2. Loading one Jac module loads all of them (start-up, bundle size)

Every emitted module imports `__boot.mjs`, and `__boot.mjs` imports the space's modules (198 of
mailflare's 199) and the 93 KB runtime `@jac/core.js`. So a test that bundles one helper, the
Worker, and the browser all parse every Jac module.

```jac
# archwire.jac
graph layers { layer all { *; } }
graph spaces { space web: node { "."; } }
graph import {
    small --> "tests/boot.test" { one }
    big --> "tests/other.test" { LOADED }
}
```
```jac
# small.jac
def one -> int { return 1; }
# big.jac
glob LOADED: int = announce();
def announce -> int { print("big.jac ran"); return 1; }
```
`replaced-by-neojac/small.ts` and `replaced-by-neojac/big.ts` hold the originals, so the forwarders
`small.ts` and `big.ts` are laid. After `neojac npm run t -- tests/boot.test.mjs`, bundling `small.ts`
in the laid tree (`.jac/test/spaces/web`) with esbuild lists these inputs:

```text
.jac/@jac/core.js
.jac/small.mjs
.jac/big.mjs        <- never imported by small.jac
.jac/__boot.mjs
small.ts
```

In mailflare this makes `src/lib/ids` (one 4-line function) a 796 KB bundle instead of 1 KB,
and the browser build gains a 450 KB `__boot` chunk (134 KB gzipped) that `/inbox` preloads.
No `jac.toml` or archwire setting changes it.

### 3. `import from js { ... }` fails in any project with an archwire

The runtime's `js` module (`js_item`, `js_bor`, ... — JavaScript's own operators, which would
skip the runtime's checks in a hot loop) cannot be imported:

```jac
# archwire.jac
graph layers { layer all { *; } }
graph spaces { space web: node { "."; } }
# probe.jac
import from js { js_item }
def first(xs: any) -> any { return js_item(xs, 0); }
```
```text
jac.toml:1:1: error[E2231]: '/home/jayanaka/.neojac/0.5.1/lib/node/crates/Cargo.toml' is a module of the project '/tmp/perf/repro-js', and no archwire.jac governs it: ...
```
(The path it names is inside neojac's own installation.) The workaround used throughout is
`globalThis.Reflect.get(o, k)` and `globalThis.X.prototype.m.call(o, ...)`, which are emitted as
direct calls.

### 4. Integer arithmetic and subscripts always go through checked helpers

On a JavaScript host, every `int` operation and every subscript is a call into the runtime, even
with every type known; sized integers add a range check on top:

```jac
glob TABLE: any = new(globalThis.Int32Array, 256);
def step(c: int, b: int) -> int {
    x: int = (c ^ b) & 0xff;
    return globalThis.Reflect.get(TABLE, x) ^ ((c >> 8) & 0xffffff);
}
def step32(c: i32, b: i32) -> i32 { return (c ^ b) & 0xff; }
def first(view: bytes) -> int { return view[0]; }
```
emits
```js
x = $j.and_i($j.xor_i(c, b), 0xff);
return $j.as_($j.dyn("^", (globalThis).Reflect.get($j.plain(TABLE), x), $j.and_i($j.shr_i(c, 8), 0xffffff)), "i");
...
return $j.fit($j.and_i($j.fit($j.xor_i(c, b), 32, false), 0xff), 32, false);
...
return $j.getitem(view, 0);
```
`shr_i` is `Math.floor(a / 2 ** b)`. This bounds byte-at-a-time code: the best Jac CRC-32 found
(slice-by-4, `DataView` reads, `Reflect.get` table lookups) is still ~30x the TypeScript.

### 5. An `obj` method's `*args` does not take JavaScript's spread arguments

A function's does; a method's does not, so a D1-style `stmt.bind(a, b, c)` needs a `Proxy`:

```jac
# bag.jac
obj Bag(globalThis.Object) {
    def take(*values: any) -> int { return len(values); }
}
def gather(*values: any) -> int { return len(values); }
```
```js
// tests/bag.test.mjs
assert.equal(gather(1, 2, 3), 3);        // passes
assert.equal(new Bag().take(1, 2, 3), 3); // fails: the method is emitted as `take(values)`
```

### What the code generation costs (not blockers, but what the rewrites avoid)

- A tuple assignment `(a, b) = (x, y)` is `$j.unpack($j.tup(x, y), 2)`: an array subclass built
  and taken apart (37% of the D1-compat profile before the fix).
- A lambda or nested `def` is built again on every call, and handed to JavaScript (a callback, a
  `.then`, a `replace` function) it gets a JavaScript face built for it each time (`js_fn`,
  `dressed`, `mark`, `defineProperty`).
- Any-typed `o.m(...)`, `o.a`, `x[i]` and operators are `$j.callattr`, `$j.getattr`,
  `$j.getitem`, `$j.dyn`: Python-semantics dispatch per use.

### 6. Values handed to a direct JavaScript call are converted, sometimes wrongly

`globalThis.X.y(arg)` with an `any` argument emits `X.y($j.plain(arg))`. `$j.plain` copies a Jac
list or a JavaScript array not marked as JavaScript's own, and turns a Jac dict, or any `Map`, into a
plain object. This makes code slow (a copy per call, so indexing an array in a loop is quadratic) and
in two cases wrong:

```jac
glob RX: any = new(globalThis.RegExp, "a", "g");
glob CACHE: any = new(globalThis.Map);

def first_index(s: str) -> any {
    for m in globalThis.String.prototype.matchAll.call(s, RX) {
        return globalThis.Reflect.get(m, "index");   # the match array is copied: no `index`
    }
    return None;
}

def cached(k: any) -> any {
    return globalThis.Map.prototype.get.call(CACHE, k);
}
```
```text
first_index("ba")  -> undefined (JavaScript gives 1)
cached("k")        -> TypeError: Method Map.prototype.get called on incompatible receiver #<Object>
```
The rewrites avoid match arrays (regex `split` with a capture group instead) and keep caches in
Jac `dict` globals.

### 7. A method read into a variable cannot be called on another object

```jac
def set_year(date: any) -> any {
    D: any = globalThis.Date.prototype;
    return D.setUTCFullYear.call(date, 2001);
}
```
```text
TypeError: Method Date.prototype.setUTCFullYear called on incompatible receiver [object Object]
```
`D.setUTCFullYear` is bound to `D` (`$j.getattr` makes bound methods), so `.call` cannot change
`this`, and the call goes through `$j.callattr`. Only the full `globalThis.Date.prototype.setUTCFullYear.call(...)`,
spelled out at each call, is a direct call.

### 8. Every call from TypeScript into a Jac `def` pays for its face

The forwarder exports `$js_fn(f)`. Its face copies the arguments (`Array.from(args, from_js)`),
binds them by the parameter list, and converts the result (`plain`):

```jac
def ident(x: any) -> any { return x; }
```
One million calls through the face take about 294 ns each, against 1.3 ns for a JavaScript
function. This is most of what is left in `jmapIds` (10x the original) and `databaseErrors` (8x):
small helpers called once per item from TypeScript. A `glob` holding a lambda skips the face. The
message stores use that, but it changes how the function is declared, so it was not applied wholesale.

### 9. `[0] * n` is quadratic

`$j.seq_mul` concatenates one copy at a time (`r = r.concat(a)` in a loop):

```jac
def zeros(n: int) -> int { d: list[int] = [0] * n; return len(d); }
```
```text
zeros(20000): 257 ms     zeros(40000): 1823 ms
```

### 10. Smaller things that got in the way

- **No `>>>` operator:** `k = x >>> 3;` gives `error[E0005]: unexpected '>'`, so unsigned shifts are
  `(x >> n) & mask`, one more checked call.
- **`len(s)` counts code points:** JavaScript code needs UTF-16 lengths, and
  `globalThis.Reflect.get(s, "length")` throws `TypeError: Reflect.get called on non-object`. The
  workaround is `globalThis.Reflect.get(globalThis.Object(s), "length")`.
- **Typed locals are checked:** a typed local assigned from a direct JavaScript call is checked
  (`$j.as_` → `fits`), which was about 10% of one parser profile. Leaving it untyped brings back `$j.dyn`
  instead.
- **Sets:** `set[str]` has no `.has` (`error[E1030]: set[str] has no method 'has'`), and `x in s`
  compiles to the same call.
- **Ordinary names are reserved:** `match`, `test`, `report`, `entry`, `override`, `bytes`, `u16` and
  `u32` cannot be used as names (`error[E0013]: '<word>' is a keyword and cannot be used as ...`).

## Reproducing the measurements

1. **The original:** check out `base/mailflare` and run `npm ci --ignore-scripts` with neojac's Node. Then copy in
   the native binaries the repo's `node_modules` built (`better-sqlite3/build`, the `esbuild` and
   `workerd` binaries), so both trees load the same code.
2. **The Jac:** `neojac npm run build` lays `.jac/test/spaces/mailflare/` and builds it.
3. **Data, in each tree:** run `wrangler d1 migrations apply DB --local`, then start `vp dev`, and
   `POST /api/seed` (the demo data, 21 messages).
4. **Run:** `perf/compare.sh <rounds> <out> original=<tree> jac=<tree> ...` alternates the start-up probe
   (`perf/startup.mjs`), the test suite, the build, a `vp preview` cold start with
   `perf/endpoints.mjs`, and the micro-benchmarks (`perf/micro.mjs`, `perf/micro2.mjs`).
   `perf/endpoints-interleaved.mjs` times several running servers request by request.
