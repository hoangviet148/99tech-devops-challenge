#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

expected="$(release_sha "$BACKEND_ROOT/current/version.json")"
required="$(release_node_version "$BACKEND_ROOT/current/version.json")"
[ -n "$required" ] || { log "no node_version in $BACKEND_ROOT/current/version.json"; exit 1; }
runtime="$("$NODE_BIN" --version 2> /dev/null)" || { log "no Node.js runtime at $NODE_BIN"; exit 1; }
runtime="${runtime#v}"
if [ "$(printf '%s\n%s\n' "$required" "$runtime" | sort -V | head -n 1)" != "$required" ]; then
  log "runtime $runtime is older than $required, the version this release was built with"
  exit 1
fi
for _ in $(seq 1 60); do
  if curl -fsS -m 2 "$HEALTH_URL/healthz" > /dev/null 2>&1; then
    actual="$(curl -fsS -m 2 "$HEALTH_URL/version" > "$BACKEND_ROOT/.served-version.json" && release_sha "$BACKEND_ROOT/.served-version.json")"
    if [ "$actual" = "$expected" ]; then
      log "serving $actual"
      exit 0
    fi
    log "serving $actual, expected $expected"
    exit 1
  fi
  sleep 1
done
log "health check did not pass within 60 s"
exit 1
