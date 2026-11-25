#!/bin/bash
# Alternating benchmark of several trees: perf/compare.sh <rounds> <out-dir> <label>=<tree> ...
# Each tree is a runnable npm tree: the original checkout, or a laid Jac tree
# (.jac/test/spaces/mailflare, laid by `neojac npm run build`), with dist/ built and the local D1
# migrated and seeded (see PERF.md). Every round runs every workload once per tree, in turn, so
# machine load falls on all trees alike. Results: <out-dir>/<workload>.tsv, one line per run.
set -u
rounds=$1; out=$2; shift 2
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$out"
port=3201
for r in $(seq 1 "$rounds"); do
	for pair in "$@"; do
		label=${pair%%=*}; tree=${pair#*=}
		for f in startup micro micro2 endpoints; do cp "$here/$f.mjs" "$tree/node_modules/.perf-$f.mjs"; done
		load=$(cut -d' ' -f1 /proc/loadavg)
		# start-up: one module bundled and imported as a test does
		for mod in src/lib/ids src/db/d1-compat; do
			echo -e "$r\t$label\t$load\t$(cd "$tree" && neojac node node_modules/.perf-startup.mjs "$tree" $mod)" >> "$out/startup.tsv"
		done
		# test suite
		t=$(mktemp)
		(cd "$tree" && /usr/bin/time -o "$t" -f "%e %U %S" neojac node --test tests/*.test.mjs > "$out/tests-$label-$r.log" 2>&1)
		counts=$(grep -E "^ℹ (pass|fail) " "$out/tests-$label-$r.log" | awk '{printf "%s=%s ", $2, $3}')
		echo -e "$r\t$label\t$load\t$(cat "$t")\t$counts" >> "$out/tests.tsv"
		# build
		(cd "$tree" && /usr/bin/time -o "$t" -f "%e %U %S" neojac npm run build > "$out/build-$label-$r.log" 2>&1)
		echo -e "$r\t$label\t$load\t$(cat "$t")\t$(grep -c 'Build complete' "$out/build-$label-$r.log")" >> "$out/build.tsv"
		# server: cold start of `vp preview`, then the endpoints
		port=$((port + 1))
		cold=$("$here/serve.sh" "$tree" $port)
		echo -e "$r\t$label\t$load\t$cold" >> "$out/serve-start.tsv"
		(cd "$tree" && neojac node node_modules/.perf-endpoints.mjs "http://localhost:$port" 20) | sed "s/^/$r\t$label\t$load\t/" >> "$out/endpoints.tsv"
		pkill -f -- "--port $port --strictPort"; sleep 1
		# micro-benchmarks
		(cd "$tree" && MICRO_MS=400 neojac node node_modules/.perf-micro.mjs "$tree"; MICRO_MS=400 neojac node node_modules/.perf-micro2.mjs "$tree") | sed "s/^/$r\t$label\t$load\t/" >> "$out/micro.tsv"
		rm -f "$t"
	done
done
