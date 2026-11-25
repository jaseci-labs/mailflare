#!/bin/bash
# usage: perf/serve.sh <built tree> <port>  - starts `vp preview` on the tree's dist/, prints
# the seconds from launch to the first answered request, and leaves the server running.
dir=$1; port=$2
cd "$dir" || exit 1
s=$(date +%s.%N)
setsid neojac npx vp preview --port "$port" --strictPort > "/tmp/preview-$port.log" 2>&1 < /dev/null &
until curl -s -o /dev/null "http://localhost:$port/api/auth/me"; do sleep 0.05; done
echo "$(echo "$(date +%s.%N) - $s" | bc)"
