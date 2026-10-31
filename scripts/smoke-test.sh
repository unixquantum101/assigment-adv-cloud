#!/usr/bin/env bash
# Hits every route through the nginx load balancer. Exit code != 0 if any fails.
# usage: smoke-test.sh http://<public-ip>
BASE="${1:?usage: smoke-test.sh http://<public-ip>}"
OUT=$(mktemp)                 # private file per run: works for any user, no stale data
trap 'rm -f "$OUT"' EXIT
fail=0
check() {
  local path="$1" expect="$2" code
  for attempt in 1 2 3 4 5 6; do
    : > "$OUT"
    code=$(curl -s -o "$OUT" -w '%{http_code}' --max-time 5 "$BASE$path")
    if [ "$code" = "200" ] && grep -q "$expect" "$OUT"; then
      echo "PASS  $path  (HTTP $code)"; return 0
    fi
    sleep 5
  done
  echo "FAIL  $path  (HTTP $code)"; fail=1
}
check /nginx-health  ok                          # nginx itself
check /              "Cloud Computing Project"   # nginx -> web
check /api/health    '"status":"ok"'             # nginx -> api
check /api/hits      '"hits"'                    # nginx -> api -> redis
exit $fail