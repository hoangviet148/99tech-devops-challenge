#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
# shellcheck source=assert.sh
. "$HERE/assert.sh"
export PATH="$HERE/bin:$PATH"

digest_of() { if command -v sha256sum > /dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

build_output() {
  mkdir -p "$T/out"
  printf '%s\n' "$1" > "$T/out/backend-aaaaaaa.tgz"
  printf '{"sha":"aaaaaaa","api_version":1}\n' > "$T/out/backend-aaaaaaa.version.json"
  jq -n --arg d "$(digest_of "$T/out/backend-aaaaaaa.tgz")" --arg run "$2" '{app: "backend", sha: "aaaaaaa", digest: $d, run_id: $run}' \
    > "$T/out/backend-aaaaaaa.build.json"
}

publish() { bash "$SCRIPTS/publish-artifact.sh" --app backend --sha aaaaaaa --dir "$T/out" --bucket artifacts --manifest-bucket manifest "$@" > "$T/out.log" 2>&1; }

record() { cat "$FAKE_AWS_STATE/s3/manifest/builds/backend/aaaaaaa.json"; }

test_first_publish_records_the_object_version() {
  build_output "bundle" 1
  publish
  assert_eq "the first publish exits 0" 0 $?
  assert_eq "the build record names the S3 object version" "$(jq -r '.VersionId' "$FAKE_AWS_STATE/meta/artifacts/backend/aaaaaaa.tgz.json")" "$(record | jq -r '.version_id')"
}

test_rerun_with_the_same_bytes_is_a_no_op() {
  build_output "bundle" 1
  publish
  build_output "bundle" 2
  publish
  assert_eq "a re-run of the build for the same commit succeeds" 0 $?
  assert_eq "the first build record stays" 1 "$(record | jq -r '.run_id')"
}

test_rerun_with_other_bytes_fails() {
  build_output "bundle" 1
  publish
  build_output "other bundle" 2
  publish
  assert_ne "different bytes under the same commit fail" 0 $?
}

test_dry_run_makes_no_aws_call() {
  build_output "bundle" 1
  publish --dry-run
  assert_eq "a dry run exits 0" 0 $?
  assert_eq "a dry run makes no AWS call" 0 "$(wc -l < "$FAKE_AWS_LOG" | tr -d ' ')"
}

run_tests test_first_publish_records_the_object_version test_rerun_with_the_same_bytes_is_a_no_op test_rerun_with_other_bytes_fails test_dry_run_makes_no_aws_call
