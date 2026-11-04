#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage: deploy-backend.sh --env ENV --sha SHA --artifact-bucket BUCKET --sha256 HEX --application APP
                         --deployment-group GROUP --target-group-arn ARN --manifest-bucket BUCKET
                         --frontend-manifest-bucket BUCKET --base-url URL [--rollback] [--require-staging-record] [--dry-run]

Deploys backend-SHA.tgz through CodeDeploy and checks the whole fleet afterwards, or with --rollback redeploys
a release recorded in the manifest. Exit codes: 0 deployed, 1 failed before the deployment started,
3 failed and rolled back, 4 failed and the rollback failed too, 5 failed and the rollback was vetoed.
EOF
}

env_name=""
sha=""
artifact_bucket=""
expected_sha256=""
application=""
group=""
target_group=""
manifest_bucket=""
frontend_manifest_bucket=""
base_url=""
rollback=0
require_staging=0
while [ $# -gt 0 ]; do
  case "$1" in
    --env) env_name="${2:-}"; shift 2 ;;
    --sha) sha="${2:-}"; shift 2 ;;
    --artifact-bucket) artifact_bucket="${2:-}"; shift 2 ;;
    --sha256) expected_sha256="${2:-}"; shift 2 ;;
    --application) application="${2:-}"; shift 2 ;;
    --deployment-group) group="${2:-}"; shift 2 ;;
    --target-group-arn) target_group="${2:-}"; shift 2 ;;
    --manifest-bucket) manifest_bucket="${2:-}"; shift 2 ;;
    --frontend-manifest-bucket) frontend_manifest_bucket="${2:-}"; shift 2 ;;
    --base-url) base_url="${2:-}"; shift 2 ;;
    --rollback) rollback=1; shift ;;
    --require-staging-record) require_staging=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done
for required in env_name sha artifact_bucket application group target_group manifest_bucket frontend_manifest_bucket base_url; do
  [ -n "${!required}" ] || { usage; die "--${required//_/-} is required"; }
done
printf '%s' "$sha" | grep -Eq '^[0-9a-f]{7,40}$' || die "--sha must be a hex commit SHA"
[ "$rollback" -eq 1 ] || printf '%s' "$expected_sha256" | grep -Eq '^[0-9a-f]{64}$' || die "--sha256 must be the hex digest from the build record"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
record_prefix="$env_name/backend/"


read_object() {
  aws_call s3api get-object --bucket "$1" --key "$2" "$work/object.json" > /dev/null
  [ "$DRY_RUN" = "1" ] && echo '{}' > "$work/object.json"
  cat "$work/object.json"
}

required_api_for_live_frontend() {
  local key min=0 value
  for key in $(list_keys "$frontend_manifest_bucket" "$env_name/frontend/" | tail -n 2); do
    value="$(read_object "$frontend_manifest_bucket" "$key" | jq -r '.min_backend_api // 0')"
    [ "$value" -gt "$min" ] && min="$value"
  done
  echo "$min"
}

artifact_version() {
  local key="backend/$1.tgz" head b64
  head="$(aws_call s3api head-object --bucket "$artifact_bucket" --key "$key" --checksum-mode ENABLED)" ||
    die "artifact $key is not in $artifact_bucket"
  if [ "$DRY_RUN" = "1" ]; then echo "dry-run"; return 0; fi
  if [ -n "$2" ]; then
    b64="$(hex_to_b64 "$2")"
    [ "$(echo "$head" | jq -r '.ChecksumSHA256 // empty')" = "$b64" ] || die "artifact $key checksum differs from the build record"
  fi
  echo "$head" | jq -r '.VersionId'
}

deploy_release() {
  local target="$1" version="$2" id statuses health targets
  id="$(aws_call deploy create-deployment --application-name "$application" --deployment-group-name "$group" \
    --deployment-config-name CodeDeployDefault.OneAtATime --file-exists-behavior OVERWRITE --description "release $target" \
    --s3-location "bucket=$artifact_bucket,key=backend/$target.tgz,bundleType=tgz,version=$version" | jq -r '.deploymentId // empty')"
  [ "$DRY_RUN" = "1" ] && id="dry-run"
  [ -n "$id" ] || return 1
  aws_call deploy wait deployment-successful --deployment-id "$id" || return 1
  [ "$DRY_RUN" = "1" ] && return 0
  read -r -a targets <<< "$(aws_call deploy list-deployment-targets --deployment-id "$id" | jq -r '.targetIds | join(" ")')"
  statuses="$(aws_call deploy batch-get-deployment-targets --deployment-id "$id" --target-ids "${targets[@]}" |
    jq -r '[.deploymentTargets[].instanceTarget.status] | unique | join(",")')"
  [ "$statuses" = "Succeeded" ] || { log "deployment $id targets: $statuses"; return 1; }
  health="$(aws_call elbv2 describe-target-health --target-group-arn "$target_group" | jq -r '[.TargetHealthDescriptions[].TargetHealth.State]')"
  printf '%s' "$health" | jq -e 'any(. == "healthy") and all(. == "healthy" or . == "draining")' > /dev/null ||
    { log "target group health: $(printf '%s' "$health" | jq -c .)"; return 1; }
  bash "$(dirname "$0")/smoke.sh" backend --base-url "$base_url" --sha "$target"
}

rollback_record() {
  local wanted="$1" key found=""
  if [ "$DRY_RUN" = "1" ]; then
    jq -n --arg sha "$wanted" '{sha: $sha, version_id: "dry-run"}'
    return 0
  fi
  for key in $(list_keys "$manifest_bucket" "$record_prefix" | grep -E -- "-${wanted}[0-9a-f]*\.json$"); do
    read_object "$manifest_bucket" "$key" > "$work/candidate.json"
    if jq -e '.kind == "deploy"' "$work/candidate.json" > /dev/null; then found="$key"; cp "$work/candidate.json" "$work/found.json"; fi
  done
  [ -n "$found" ] || die "release $wanted was never deployed to $env_name, so it is not a rollback target"
  cat "$work/found.json"
}

write_record() {
  local previous="$1" version="$2" api="$3" kind="$4" key
  key="$record_prefix$(utc_stamp)-$sha.json"
  jq -n --arg sha "$sha" --arg previous "$previous" --arg version "$version" --argjson api "$api" --arg kind "$kind" \
    --arg digest "${expected_sha256:-rollback}" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg run "${GITHUB_RUN_ID:-local}" \
    '{sha: $sha, previous_sha: $previous, version_id: $version, api_version: $api, digest: $digest, kind: $kind, deployed_at: $at, run_id: $run}' \
    > "$work/record.json"
  put_immutable "$manifest_bucket" "$key" "$work/record.json" "no-cache"
}

latest="$(list_keys "$manifest_bucket" "$record_prefix" | tail -n 1)"
previous_sha=""
previous_version=""
previous_api=0
if [ -n "$latest" ]; then
  read_object "$manifest_bucket" "$latest" > "$work/previous.json"
  previous_sha="$(jq -r '.sha // empty' "$work/previous.json")"
  previous_version="$(jq -r '.version_id // empty' "$work/previous.json")"
  previous_api="$(jq -r '.api_version // 0' "$work/previous.json")"
fi

if [ "$rollback" -eq 1 ]; then
  rollback_record "$sha" > "$work/target.json"
  sha="$(jq -r '.sha' "$work/target.json")"
  expected_sha256="$(jq -r '.digest // empty' "$work/target.json")"
  version="$(artifact_version "$sha" "")"
  [ "$DRY_RUN" = "1" ] || [ "$(jq -r '.version_id' "$work/target.json")" = "$version" ] ||
    die "the artifact of $sha is no longer the object version that $env_name ran"
else
  version="$(artifact_version "$sha" "$expected_sha256")"
  if [ "$require_staging" -eq 1 ]; then
    require_build_record "$manifest_bucket" backend "$sha" "$expected_sha256" "$version"
    require_staging_record "$manifest_bucket" backend "$expected_sha256"
  fi
fi
api_version="$(aws_call s3api get-object --bucket "$artifact_bucket" --key "backend/$sha.version.json" "$work/version.json" > /dev/null && jq -r '.api_version // 0' "$work/version.json" 2> /dev/null || echo 0)"
[ "$DRY_RUN" = "1" ] && api_version=1

if [ "$DRY_RUN" != "1" ]; then
  required="$(required_api_for_live_frontend)"
  [ "$api_version" -ge "$required" ] || die "release $sha serves api_version $api_version, the live frontend needs $required"
fi

kind="deploy"
[ "$rollback" -eq 1 ] && kind="rollback"
if deploy_release "$sha" "$version"; then
  write_record "$previous_sha" "$version" "$api_version" "$kind"
  log "release $sha deployed"
  exit 0
fi

if [ "$rollback" -eq 1 ] || [ -z "$previous_sha" ]; then
  log "release $sha failed and there is nothing to return to"
  exit 4
fi
required="$(required_api_for_live_frontend)"
if [ "$previous_api" -lt "$required" ]; then
  log "release $sha failed, and returning to $previous_sha is vetoed: it serves api_version $previous_api, the live frontend needs $required"
  exit 5
fi
log "release $sha failed, returning to $previous_sha"
if deploy_release "$previous_sha" "$previous_version"; then exit 3; fi
log "previous release $previous_sha failed too"
exit 4
