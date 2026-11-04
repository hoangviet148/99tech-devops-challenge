#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
# shellcheck source=assert.sh
. "$HERE/assert.sh"
export PATH="$HERE/bin:$PATH"

publish_artifact() {
  local sha="$1" api="${2:-1}" out="$T/out"
  mkdir -p "$out"
  printf 'bundle %s\n' "$sha" > "$out/backend-$sha.tgz"
  printf '{"sha":"%s","api_version":%s}\n' "$sha" "$api" > "$out/backend-$sha.version.json"
  jq -n --arg sha "$sha" --arg d "$(digest_of "$out/backend-$sha.tgz")" '{app: "backend", sha: $sha, digest: $d}' > "$out/backend-$sha.build.json"
  bash "$SCRIPTS/publish-artifact.sh" --app backend --sha "$sha" --dir "$out" --bucket artifacts --manifest-bucket manifest > /dev/null 2>&1 ||
    { echo "publish of $sha failed" >&2; return 1; }
  digest_of "$out/backend-$sha.tgz"
}

deploy_production() {
  bash "$SCRIPTS/deploy-backend.sh" --env production --artifact-bucket artifacts --application backend \
    --deployment-group backend-production --target-group-arn arn:tg --manifest-bucket manifest --frontend-manifest-bucket manifest \
    --base-url http://backend.test --require-staging-record "$@" > "$T/out.log" 2>&1
}

digest_of() { if command -v sha256sum > /dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

live_frontend_needs() {
  printf '{"sha":"fffffff","min_backend_api":%s}\n' "$1" > "$T/frontend-record.json"
  aws s3api put-object --bucket manifest --key "staging/frontend/20261104T000000.000000Z-fffffff.json" --body "$T/frontend-record.json" > /dev/null
}

deploy() {
  bash "$SCRIPTS/deploy-backend.sh" --env staging --artifact-bucket artifacts --application backend \
    --deployment-group backend-staging --target-group-arn arn:tg --manifest-bucket manifest \
    --frontend-manifest-bucket manifest --base-url http://backend.test "$@" > "$T/out.log" 2>&1
}

deployments() { grep -c '^deploy create-deployment' "$FAKE_AWS_LOG" | tr -d ' '; }

first_release() {
  local digest
  digest="$(publish_artifact aaaaaaa 1)"
  FAKE_BACKEND_SHA=aaaaaaa deploy --sha aaaaaaa --sha256 "$digest"
}

test_deploy_checks_the_whole_fleet() {
  local digest
  live_frontend_needs 1
  digest="$(publish_artifact aaaaaaa 1)"
  : > "$FAKE_AWS_LOG"
  FAKE_BACKEND_SHA=aaaaaaa deploy --sha aaaaaaa --sha256 "$digest"
  assert_eq "a healthy deploy exits 0" 0 $?
  assert_logged "the deployment pins the S3 object version" "version=v"
  assert_logged "every deployment target is read" "deploy batch-get-deployment-targets"
  assert_logged "target group health is read" "elbv2 describe-target-health"
  assert_logged "a deployment record is written" "put-object --bucket manifest --key staging/backend/"
}

test_wrong_checksum_never_deploys() {
  publish_artifact aaaaaaa 1 > /dev/null
  deploy --sha aaaaaaa --sha256 1111111111111111111111111111111111111111111111111111111111111111
  assert_ne "a checksum mismatch fails" 0 $?
  assert_eq "no deployment is created" 0 "$(deployments)"
}

test_missing_artifact_never_deploys() {
  deploy --sha bbbbbbb --sha256 1111111111111111111111111111111111111111111111111111111111111111
  assert_ne "a missing artifact fails" 0 $?
  assert_eq "no deployment is created" 0 "$(deployments)"
}

test_failed_last_instance_rolls_back() {
  local digest
  first_release
  digest="$(publish_artifact bbbbbbb 1)"
  FAKE_TARGET_STATUSES="Succeeded,Failed Succeeded,Succeeded" FAKE_BACKEND_SHA=aaaaaaa deploy --sha bbbbbbb --sha256 "$digest"
  assert_eq "a deployment whose last instance failed exits 3 after the rollback" 3 $?
  assert_eq "the previous release is deployed again" 3 "$(deployments)"
}

test_failed_smoke_after_success_rolls_back() {
  local digest
  first_release
  digest="$(publish_artifact bbbbbbb 1)"
  FAKE_BACKEND_SHA=aaaaaaa deploy --sha bbbbbbb --sha256 "$digest"
  assert_eq "a release that fails its smoke test exits 3 after the rollback" 3 $?
}

test_vetoed_rollback_stops_and_pages() {
  local digest
  first_release
  live_frontend_needs 2
  digest="$(publish_artifact bbbbbbb 2)"
  FAKE_TARGET_STATUSES="Succeeded,Failed" FAKE_BACKEND_SHA=aaaaaaa deploy --sha bbbbbbb --sha256 "$digest"
  assert_eq "a rollback below the live frontend's API needs is vetoed with exit 5" 5 $?
  assert_eq "the vetoed rollback creates no deployment" 2 "$(deployments)"
}

test_release_below_frontend_needs_is_refused() {
  local digest
  live_frontend_needs 2
  digest="$(publish_artifact aaaaaaa 1)"
  deploy --sha aaaaaaa --sha256 "$digest"
  assert_ne "a release below the live frontend's API needs is refused" 0 $?
  assert_eq "no deployment is created" 0 "$(deployments)"
}

test_rollback_to_retained_release() {
  local digest
  first_release
  digest="$(publish_artifact bbbbbbb 1)"
  FAKE_BACKEND_SHA=bbbbbbb deploy --sha bbbbbbb --sha256 "$digest"
  FAKE_BACKEND_SHA=aaaaaaa deploy --sha aaaaaaa --rollback
  assert_eq "a rollback to a retained release exits 0" 0 $?
}

test_rollback_to_missing_release_is_refused() {
  first_release
  deploy --sha ccccccc --rollback
  assert_ne "a rollback to a release that is not retained fails" 0 $?
}

test_dry_run_makes_no_aws_call() {
  deploy --sha aaaaaaa --sha256 1111111111111111111111111111111111111111111111111111111111111111 --dry-run
  assert_eq "a dry run exits 0" 0 $?
  assert_eq "a dry run makes no AWS call" 0 "$(wc -l < "$FAKE_AWS_LOG" | tr -d ' ')"
}

test_production_requires_staging_record() {
  local digest
  digest="$(publish_artifact aaaaaaa 1)"
  FAKE_BACKEND_SHA=aaaaaaa deploy_production --sha aaaaaaa --sha256 "$digest"
  assert_ne "production without a staging record is refused" 0 $?
  assert_eq "no deployment is created without staging evidence" 0 "$(deployments)"
  FAKE_BACKEND_SHA=aaaaaaa deploy --sha aaaaaaa --sha256 "$digest"
  FAKE_BACKEND_SHA=aaaaaaa deploy_production --sha aaaaaaa --sha256 "$digest"
  assert_eq "production with a staging record of the same digest deploys" 0 $?
}

test_production_refuses_a_build_record_of_another_digest() {
  local digest
  printf 'bundle aaaaaaa\n' > "$T/backend.tgz"
  printf '{"sha":"aaaaaaa","api_version":1}\n' > "$T/version.json"
  aws s3api put-object --bucket artifacts --key backend/aaaaaaa.tgz --body "$T/backend.tgz" --if-none-match '*' > /dev/null
  aws s3api put-object --bucket artifacts --key backend/aaaaaaa.version.json --body "$T/version.json" --if-none-match '*' > /dev/null
  printf '{"sha":"aaaaaaa","digest":"%s","version_id":"v0"}\n' "$(printf '%064d' 0)" > "$T/build.json"
  aws s3api put-object --bucket manifest --key builds/backend/aaaaaaa.json --body "$T/build.json" --if-none-match '*' > /dev/null
  digest="$(digest_of "$T/backend.tgz")"
  FAKE_BACKEND_SHA=aaaaaaa deploy --sha aaaaaaa --sha256 "$digest"
  : > "$FAKE_AWS_LOG"
  FAKE_BACKEND_SHA=aaaaaaa deploy_production --sha aaaaaaa --sha256 "$digest"
  assert_ne "production refuses an artifact that the build record does not name" 0 $?
  assert_eq "no production deployment is created" 0 "$(deployments)"
}

test_rollback_to_a_release_never_deployed_here_is_refused() {
  local digest
  first_release
  digest="$(publish_artifact bbbbbbb 1)"
  [ -n "$digest" ]
  : > "$FAKE_AWS_LOG"
  deploy --sha bbbbbbb --rollback
  assert_ne "a rollback to a release that this environment never ran is refused" 0 $?
  assert_eq "no deployment is created" 0 "$(deployments)"
}

test_draining_target_does_not_fail_the_check() {
  local digest
  digest="$(publish_artifact aaaaaaa 1)"
  FAKE_TARGET_HEALTH="healthy,draining" FAKE_BACKEND_SHA=aaaaaaa deploy --sha aaaaaaa --sha256 "$digest"
  assert_eq "a target that is draining after a scale-in does not fail the deploy" 0 $?
}

test_no_healthy_target_fails_the_check() {
  local digest
  first_release
  digest="$(publish_artifact bbbbbbb 1)"
  FAKE_TARGET_HEALTH="draining,draining healthy,healthy" FAKE_BACKEND_SHA=aaaaaaa deploy --sha bbbbbbb --sha256 "$digest"
  assert_eq "a fleet with no healthy target fails and returns to the previous release" 3 $?
}

run_tests test_production_requires_staging_record test_production_refuses_a_build_record_of_another_digest \
  test_rollback_to_a_release_never_deployed_here_is_refused test_draining_target_does_not_fail_the_check test_no_healthy_target_fails_the_check \
  test_deploy_checks_the_whole_fleet test_wrong_checksum_never_deploys test_missing_artifact_never_deploys \
  test_failed_last_instance_rolls_back test_failed_smoke_after_success_rolls_back test_vetoed_rollback_stops_and_pages \
  test_release_below_frontend_needs_is_refused test_rollback_to_retained_release test_rollback_to_missing_release_is_refused \
  test_dry_run_makes_no_aws_call
