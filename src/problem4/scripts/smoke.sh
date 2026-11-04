#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

usage() {
  echo "Usage: smoke.sh frontend|backend --base-url URL --sha SHA" >&2
}

kind="${1:-}"
shift || true
base=""
sha=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base-url) base="${2:-}"; shift 2 ;;
    --sha) sha="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[ -n "$base" ] && [ -n "$sha" ] || { usage; exit 2; }
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

check() {
  local label="$1" url="$2" want_code="$3" want_type="$4" result code ctype
  result="$(http_get "$url" "$work/body")"
  code="${result%% *}"
  ctype="${result#* }"
  if [ "$code" != "$want_code" ]; then log "smoke $label: HTTP $code from $url, expected $want_code"; return 1; fi
  case "$ctype" in "$want_type"*) ;; *) log "smoke $label: content type $ctype from $url, expected $want_type"; return 1 ;; esac
  return 0
}

smoke_frontend() {
  local entry
  check "index" "$base/" 200 "text/html" || return 1
  grep -q "name=\"release-sha\" content=\"$sha\"" "$work/body" || { log "smoke index: release $sha is not active"; return 1; }
  entry="$(grep -o 'src="/assets/[^"]*\.js"' "$work/body" | head -n 1 | sed -e 's/^src="//' -e 's/"$//')"
  [ -n "$entry" ] || { log "smoke index: no entry script"; return 1; }
  check "entry script" "$base$entry" 200 "text/javascript" || return 1
  [ -s "$work/body" ] || { log "smoke entry script: empty body"; return 1; }
  check "deep link" "$base/details" 200 "text/html" || return 1
  check "release config" "$base/releases/$sha/config.json" 200 "application/json" || return 1
  jq -e '.environment and .apiBaseUrl' "$work/body" > /dev/null || { log "smoke release config: invalid JSON"; return 1; }
  log "smoke frontend: release $sha serves"
}

smoke_backend() {
  local served
  check "healthz" "$base/healthz" 200 "application/json" || return 1
  check "version" "$base/version" 200 "application/json" || return 1
  served="$(jq -r '.sha // empty' "$work/body")"
  [ "$served" = "$sha" ] || { log "smoke version: serving $served, expected $sha"; return 1; }
  log "smoke backend: release $sha serves"
}

case "$kind" in
  frontend) smoke_frontend ;;
  backend) smoke_backend ;;
  *) usage; exit 2 ;;
esac
