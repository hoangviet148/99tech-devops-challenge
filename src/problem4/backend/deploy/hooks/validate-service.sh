#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

expected="$(release_sha "$BACKEND_ROOT/current/version.json")"
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
