#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

usage() { echo "Usage: check-forward.sh --app APP --env ENV --sha SHA --manifest-bucket BUCKET [--rollback] [--dry-run]" >&2; }

app=""
env_name=""
sha=""
manifest_bucket=""
rollback=0
while [ $# -gt 0 ]; do
  case "$1" in
    --app) app="${2:-}"; shift 2 ;;
    --env) env_name="${2:-}"; shift 2 ;;
    --sha) sha="${2:-}"; shift 2 ;;
    --manifest-bucket) manifest_bucket="${2:-}"; shift 2 ;;
    --rollback) rollback=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) usage; exit 2 ;;
  esac
done
case "$app" in backend|frontend) ;; *) die "--app must be backend or frontend" ;; esac
[ -n "$env_name" ] && [ -n "$sha" ] && [ -n "$manifest_bucket" ] || { usage; exit 2; }

if [ "$DRY_RUN" = "1" ]; then
  log "dry-run: would require $sha to descend from the $app release deployed in $env_name"
  exit 0
fi
latest="$(list_keys "$manifest_bucket" "$env_name/$app/" | tail -n 1)"
if [ -z "$latest" ]; then
  log "no $app release is recorded in $env_name yet"
  exit 0
fi
deployed="$(read_json "$manifest_bucket" "$latest" | jq -r '.sha // empty')"
[ -n "$deployed" ] || die "the latest record $latest names no sha"
if [ "$deployed" = "$sha" ]; then
  log "$sha is already the deployed $app release in $env_name"
  exit 0
fi
if [ "$rollback" -eq 1 ]; then
  log "rollback of $app in $env_name from $deployed to $sha"
  exit 0
fi
git cat-file -e "$deployed^{commit}" 2> /dev/null || die "the deployed commit $deployed is not in this checkout, which needs the full history"
git cat-file -e "$sha^{commit}" 2> /dev/null || die "commit $sha is not in this checkout"
git merge-base --is-ancestor "$deployed" "$sha" ||
  die "$sha does not descend from $deployed, which $env_name already runs. Use rollback.yml to go back on purpose"
log "$sha descends from the deployed $deployed"
