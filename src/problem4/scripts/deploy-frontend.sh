#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage: deploy-frontend.sh --env ENV --sha SHA --bucket BUCKET --distribution ID --manifest-bucket BUCKET
                          --base-url URL --backend-url URL (--artifact FILE [--sha256 HEX] | --rollback)
                          [--require-staging-record] [--dry-run]

Deploys a frontend release built by build-frontend.sh, or with --rollback reactivates a release that is still
retained in the bucket. Exit codes: 0 deployed, 1 failed before activation, 3 failed and rolled back,
4 failed and the rollback failed too.
EOF
}

env_name=""
sha=""
artifact=""
expected_sha256=""
bucket=""
distribution=""
manifest_bucket=""
base_url=""
backend_url=""
rollback=0
require_staging=0
while [ $# -gt 0 ]; do
  case "$1" in
    --env) env_name="${2:-}"; shift 2 ;;
    --sha) sha="${2:-}"; shift 2 ;;
    --artifact) artifact="${2:-}"; shift 2 ;;
    --sha256) expected_sha256="${2:-}"; shift 2 ;;
    --bucket) bucket="${2:-}"; shift 2 ;;
    --distribution) distribution="${2:-}"; shift 2 ;;
    --manifest-bucket) manifest_bucket="${2:-}"; shift 2 ;;
    --base-url) base_url="${2:-}"; shift 2 ;;
    --backend-url) backend_url="${2:-}"; shift 2 ;;
    --rollback) rollback=1; shift ;;
    --require-staging-record) require_staging=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done
for required in env_name sha bucket distribution manifest_bucket base_url backend_url; do
  [ -n "${!required}" ] || { usage; die "--${required//_/-} is required"; }
done
printf '%s' "$sha" | grep -Eq '^[0-9a-f]{7,40}$' || die "--sha must be a hex commit SHA"
[ "$rollback" -eq 1 ] || [ -n "$artifact" ] || die "--artifact or --rollback is required"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
record_prefix="$env_name/frontend/"

latest_record() {
  aws_call s3api list-objects-v2 --bucket "$manifest_bucket" --prefix "$record_prefix" | jq -r '[.Contents[]?.Key] | sort | last // empty'
}

read_record() {
  [ -n "$1" ] || return 0
  aws_call s3api get-object --bucket "$manifest_bucket" --key "$1" "$work/record.json" > /dev/null
  [ "$DRY_RUN" = "1" ] && echo '{}' > "$work/record.json"
  cat "$work/record.json"
}

backend_api_version() {
  local result
  result="$(http_get "$backend_url/version" "$work/backend-version.json")"
  [ "${result%% *}" = "200" ] || { echo 0; return 0; }
  jq -r '.api_version // 0' "$work/backend-version.json"
}

require_compatible_backend() {
  local min="$1" have
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: would require backend api_version >= $min at $backend_url"
    return 0
  fi
  have="$(backend_api_version)"
  [ "$have" -ge "$min" ] || die "backend at $backend_url serves api_version $have, release needs $min"
}

activate() {
  local target="$1" invalidation
  aws_call s3api copy-object --bucket "$bucket" --copy-source "$bucket/releases/$target/index.html" --key index.html \
    --metadata-directive REPLACE --cache-control no-cache --content-type "text/html; charset=utf-8" > /dev/null
  invalidation="$(aws_call cloudfront create-invalidation --distribution-id "$distribution" --paths / /index.html | jq -r '.Invalidation.Id // empty')"
  aws_call cloudfront wait invalidation-completed --distribution-id "$distribution" --id "${invalidation:-dry-run}"
}

smoke() {
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: would run smoke.sh frontend against $base_url for $1"
    return 0
  fi
  bash "$(dirname "$0")/smoke.sh" frontend --base-url "$base_url" --sha "$1"
}

write_record() {
  local previous="$1" digest="$2" min_api="$3" kind="$4" key
  key="$record_prefix$(utc_stamp)-$sha.json"
  jq -n --arg sha "$sha" --arg previous "$previous" --arg digest "$digest" --argjson min "$min_api" --arg kind "$kind" \
    --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg run "${GITHUB_RUN_ID:-local}" \
    '{sha: $sha, previous_sha: $previous, digest: $digest, min_backend_api: $min, kind: $kind, activated_at: $at, run_id: $run}' \
    > "$work/new-record.json"
  put_immutable "$manifest_bucket" "$key" "$work/new-record.json" "no-cache"
  log "recorded $kind of $sha in $key"
}

if [ "$rollback" -eq 0 ]; then
  if [ -n "$expected_sha256" ]; then
    [ "$(sha256_file "$artifact")" = "$expected_sha256" ] || die "artifact checksum differs from the build record"
  fi
  digest="$(sha256_file "$artifact")"
  tar -xzf "$artifact" -C "$work"
  [ "$(jq -r '.sha' "$work/version.json")" = "$sha" ] || die "artifact was built from another commit"
  [ -f "$work/config/$env_name.json" ] || die "artifact has no configuration for $env_name"
  [ -n "$(ls -A "$work/dist/assets" 2> /dev/null)" ] || die "artifact has no assets"
  min_api="$(jq -r '.min_backend_api' "$work/release.json")"
fi

previous_sha="$(read_record "$(latest_record)" | jq -r '.sha // empty')"

if [ "$rollback" -eq 1 ]; then
  aws_call s3api head-object --bucket "$bucket" --key "releases/$sha/index.html" > /dev/null 2>&1 ||
    die "release $sha is no longer retained in $bucket"
  aws_call s3api get-object --bucket "$bucket" --key "releases/$sha/release.json" "$work/release.json" > /dev/null
  [ "$DRY_RUN" = "1" ] && echo '{"min_backend_api": 1}' > "$work/release.json"
  min_api="$(jq -r '.min_backend_api' "$work/release.json")"
  require_compatible_backend "$min_api"
  if activate "$sha" && smoke "$sha"; then
    write_record "$previous_sha" "rollback" "$min_api" "rollback"
    exit 0
  fi
  log "rollback to $sha failed"
  exit 4
fi

if [ "$require_staging" -eq 1 ]; then
  require_build_record "$manifest_bucket" frontend "$sha" "$digest"
  require_staging_record "$manifest_bucket" frontend "$digest"
fi
require_compatible_backend "$min_api"

for asset in "$work"/dist/assets/*; do
  put_immutable "$bucket" "assets/$(basename "$asset")" "$asset" "public, max-age=31536000, immutable"
done
put_immutable "$bucket" "releases/$sha/config.json" "$work/config/$env_name.json" "no-cache"
put_immutable "$bucket" "releases/$sha/version.json" "$work/version.json" "no-cache"
put_immutable "$bucket" "releases/$sha/release.json" "$work/release.json" "no-cache"
put_immutable "$bucket" "releases/$sha/manifest.json" "$work/dist/.vite/manifest.json" "no-cache"
put_immutable "$bucket" "releases/$sha/index.html" "$work/dist/index.html" "no-cache"

if activate "$sha" && smoke "$sha"; then
  write_record "$previous_sha" "$digest" "$min_api" "deploy"
  exit 0
fi

if [ -z "$previous_sha" ]; then
  log "release $sha failed after activation and there is no previous release to return to"
  exit 4
fi
log "release $sha failed after activation, returning to $previous_sha"
if activate "$previous_sha" && smoke "$previous_sha"; then exit 3; fi
log "previous release $previous_sha failed too"
exit 4
