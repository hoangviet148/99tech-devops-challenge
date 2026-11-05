#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
# shellcheck source=assert.sh
. "$HERE/assert.sh"
export PATH="$HERE/bin:$PATH"

make_artifact() {
  local sha="$1" out="$2" mode="${3:-ok}" d entry
  d="$(mktemp -d)"
  mkdir -p "$d/dist/assets" "$d/dist/.vite" "$d/config"
  printf 'console.log("%s");\n' "$sha" > "$d/dist/assets/index-$sha.js"
  entry="index-$sha.js"
  [ "$mode" = "broken-entry" ] && entry="index-missing.js"
  printf '<!doctype html><html><head><meta name="release-sha" content="%s" /><script type="module" src="/assets/%s"></script></head><body></body></html>\n' \
    "$sha" "$entry" > "$d/dist/index.html"
  echo '{}' > "$d/dist/.vite/manifest.json"
  for e in staging production; do
    printf '{"environment":"%s","apiBaseUrl":"https://api.example.com","versionCheckSeconds":600}\n' "$e" > "$d/config/$e.json"
  done
  if [ "$mode" = "other-config" ]; then
    printf '{"environment":"staging","apiBaseUrl":"https://other.example.com","versionCheckSeconds":60}\n' > "$d/config/staging.json"
  fi
  printf '{"sha":"%s","committed_at":"2026-11-04T00:00:00Z"}\n' "$sha" > "$d/version.json"
  printf '{"sha":"%s","min_backend_api":1}\n' "$sha" > "$d/release.json"
  tar -czf "$out" -C "$d" .
  rm -rf "$d"
}

deploy() {
  bash "$SCRIPTS/deploy-frontend.sh" --env staging --bucket frontend-bucket --distribution EFAKE \
    --manifest-bucket manifest-bucket --base-url http://frontend.test --backend-url http://backend.test "$@" > "$T/out.log" 2>&1
}

active_sha() { sed -n 's/.*name="release-sha" content="\([0-9a-f]*\)".*/\1/p' "$FAKE_AWS_STATE/s3/frontend-bucket/index.html" 2> /dev/null; }

test_first_deploy_activates_last() {
  make_artifact aaaaaaa "$T/a.tgz"
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  assert_eq "first deploy exits 0" 0 $?
  assert_eq "release aaaaaaa is active" aaaaaaa "$(active_sha)"
  assert_before "assets upload before the release index" "put-object --bucket frontend-bucket --key assets/" "put-object --bucket frontend-bucket --key releases/aaaaaaa/index.html"
  assert_before "release files upload before activation" "put-object --bucket frontend-bucket --key releases/aaaaaaa/index.html" "copy-object"
  assert_before "invalidation follows activation" "copy-object" "cloudfront create-invalidation"
  assert_not_logged "no call uses --delete" "--delete"
  assert_logged "a deployment record is written" "put-object --bucket manifest-bucket --key staging/frontend/"
}

test_same_release_twice_is_a_no_op() {
  make_artifact aaaaaaa "$T/a.tgz"
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  assert_eq "a repeated deploy of identical bytes exits 0" 0 $?
}

test_same_sha_other_config_is_refused() {
  make_artifact aaaaaaa "$T/a.tgz"
  make_artifact aaaaaaa "$T/a2.tgz" other-config
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  : > "$FAKE_AWS_LOG"
  deploy --sha aaaaaaa --artifact "$T/a2.tgz"
  assert_ne "a different configuration under the same SHA fails" 0 $?
  assert_not_logged "the conflicting release is never activated" "copy-object"
}

test_upload_failure_stops_before_activation() {
  make_artifact aaaaaaa "$T/a.tgz"
  FAKE_AWS_FAIL="s3api put-object releases/aaaaaaa/index.html" deploy --sha aaaaaaa --artifact "$T/a.tgz"
  assert_ne "a failed upload fails the deploy" 0 $?
  assert_not_logged "nothing is activated after a failed upload" "copy-object"
}

test_wrong_checksum_makes_no_aws_call() {
  make_artifact aaaaaaa "$T/a.tgz"
  deploy --sha aaaaaaa --artifact "$T/a.tgz" --sha256 0000000000000000000000000000000000000000000000000000000000000000
  assert_ne "a checksum mismatch fails" 0 $?
  assert_eq "no AWS call happens after a checksum mismatch" 0 "$(wc -l < "$FAKE_AWS_LOG" | tr -d ' ')"
}

test_incompatible_backend_blocks_activation() {
  make_artifact aaaaaaa "$T/a.tgz"
  FAKE_BACKEND_API=0 deploy --sha aaaaaaa --artifact "$T/a.tgz"
  assert_ne "a backend below min_backend_api blocks the deploy" 0 $?
  assert_not_logged "nothing is uploaded for an incompatible backend" "put-object --bucket frontend-bucket"
}

test_failed_smoke_returns_to_previous() {
  make_artifact aaaaaaa "$T/a.tgz"
  make_artifact bbbbbbb "$T/b.tgz" broken-entry
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  deploy --sha bbbbbbb --artifact "$T/b.tgz"
  assert_eq "a release that fails its smoke test exits 3" 3 $?
  assert_eq "the previous release is active again" aaaaaaa "$(active_sha)"
}

test_failed_invalidation_wait_returns_to_previous() {
  make_artifact aaaaaaa "$T/a.tgz"
  make_artifact bbbbbbb "$T/b.tgz"
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  FAKE_INVALIDATION_WAIT=fail deploy --sha bbbbbbb --artifact "$T/b.tgz"
  assert_ne "a failed invalidation wait does not report success" 0 $?
}

test_rollback_to_retained_release() {
  make_artifact aaaaaaa "$T/a.tgz"
  make_artifact bbbbbbb "$T/b.tgz"
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  deploy --sha bbbbbbb --artifact "$T/b.tgz"
  deploy --sha aaaaaaa --rollback
  assert_eq "a rollback to a retained release exits 0" 0 $?
  assert_eq "the rollback target is active" aaaaaaa "$(active_sha)"
}

test_rollback_to_missing_release_is_refused() {
  make_artifact aaaaaaa "$T/a.tgz"
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  deploy --sha ccccccc --rollback
  assert_ne "a rollback to a release that is not retained fails" 0 $?
  assert_eq "the active release is unchanged" aaaaaaa "$(active_sha)"
}

test_dry_run_makes_no_aws_call() {
  make_artifact aaaaaaa "$T/a.tgz"
  deploy --sha aaaaaaa --artifact "$T/a.tgz" --dry-run
  assert_eq "a dry run exits 0" 0 $?
  assert_eq "a dry run makes no AWS call" 0 "$(wc -l < "$FAKE_AWS_LOG" | tr -d ' ')"
}

deploy_production() {
  FAKE_FRONTEND_BUCKET=frontend-production-bucket bash "$SCRIPTS/deploy-frontend.sh" --env production --bucket frontend-production-bucket \
    --distribution EFAKE --manifest-bucket manifest-bucket --base-url http://frontend.test --backend-url http://backend.test \
    --require-staging-record "$@" > "$T/out.log" 2>&1
}

build_record() {
  local sha="$1" digest="$2"
  printf '{"app":"frontend","sha":"%s","digest":"%s","version_id":"v1"}\n' "$sha" "$digest" > "$T/build-$sha.json"
  aws s3api put-object --bucket manifest-bucket --key "builds/frontend/$sha.json" --body "$T/build-$sha.json" --if-none-match '*' > /dev/null
}

digest_of() { if command -v sha256sum > /dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

test_production_requires_staging_record() {
  make_artifact aaaaaaa "$T/a.tgz"
  make_artifact bbbbbbb "$T/b.tgz"
  build_record aaaaaaa "$(digest_of "$T/a.tgz")"
  build_record bbbbbbb "$(digest_of "$T/b.tgz")"
  deploy_production --sha aaaaaaa --artifact "$T/a.tgz"
  assert_ne "production without a staging record is refused" 0 $?
  assert_not_logged "nothing is uploaded without staging evidence" "put-object --bucket frontend-production-bucket"
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  deploy_production --sha aaaaaaa --artifact "$T/a.tgz"
  assert_eq "production with a staging record of the same digest deploys" 0 $?
  deploy_production --sha bbbbbbb --artifact "$T/b.tgz"
  assert_ne "a staging record of another digest does not count" 0 $?
}

test_production_requires_the_build_record_digest() {
  make_artifact aaaaaaa "$T/a.tgz"
  build_record aaaaaaa "$(printf '%064d' 0)"
  deploy --sha aaaaaaa --artifact "$T/a.tgz"
  deploy_production --sha aaaaaaa --artifact "$T/a.tgz"
  assert_ne "production refuses an artifact that the build record does not name" 0 $?
  assert_not_logged "nothing reaches the production bucket" "put-object --bucket frontend-production-bucket"
}

run_tests test_production_requires_the_build_record_digest test_production_requires_staging_record test_first_deploy_activates_last test_same_release_twice_is_a_no_op test_same_sha_other_config_is_refused \
  test_upload_failure_stops_before_activation test_wrong_checksum_makes_no_aws_call test_incompatible_backend_blocks_activation \
  test_failed_smoke_returns_to_previous test_failed_invalidation_wait_returns_to_previous test_rollback_to_retained_release \
  test_rollback_to_missing_release_is_refused test_dry_run_makes_no_aws_call
