#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

audience="sts.amazonaws.com"
expect_sub=""
require_sub=0
while [ $# -gt 0 ]; do
  case "$1" in
    --audience) audience="${2:-}"; shift 2 ;;
    --expect-sub) expect_sub="${2:-}"; shift 2 ;;
    --require-sub) require_sub=1; shift ;;
    *) echo "Usage: oidc-claims.sh [--audience AUD] [--expect-sub SUB] [--require-sub]" >&2; exit 2 ;;
  esac
done
[ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] && [ -n "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ] ||
  die "no OIDC token endpoint, the job needs the id-token: write permission"

token="$(curl -sS -m 10 -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$audience" | jq -r '.value // empty')"
[ -n "$token" ] || die "the OIDC token request returned no token"
echo "::add-mask::$token"
payload="$(printf '%s' "$token" | cut -d. -f2 | tr '_-' '/+')"
while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done
claims="$(printf '%s' "$payload" | base64 -d 2> /dev/null || printf '%s' "$payload" | base64 -D)"
printf '%s' "$claims" | jq '{sub, aud, repository, repository_id, repository_owner_id, ref, environment, job_workflow_ref}'
[ "$(printf '%s' "$claims" | jq -r '.aud')" = "$audience" ] || die "token audience differs from $audience"
if [ -z "$expect_sub" ]; then
  [ "$require_sub" -eq 0 ] || die "no expected subject is pinned, and a deploy with AWS access needs one"
  log "no expected subject is configured yet, pin the sub printed above in OIDC_EXPECTED_SUB"
  exit 0
fi
[ "$(printf '%s' "$claims" | jq -r '.sub')" = "$expect_sub" ] || die "token subject differs from the pinned $expect_sub"
log "token subject matches the pinned value"
