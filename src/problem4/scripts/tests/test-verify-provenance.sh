#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
# shellcheck source=assert.sh
. "$HERE/assert.sh"
export PATH="$HERE/bin:$PATH"

REPO="conbosua/ship-it-twice"
SIGNER=".github/workflows/backend-cd.yml"

digest_of() { if command -v sha256sum > /dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

attest() {
  local workflow="$1" ref="$2" runner="$3"
  mkdir -p "$FAKE_GH_ATTESTATIONS"
  jq -n --arg uri "https://github.com/$REPO/$workflow@$ref" --arg ref "$ref" --arg runner "$runner" \
    '[{verificationResult: {signature: {certificate: {buildSignerURI: $uri, sourceRepositoryRef: $ref, runnerEnvironment: $runner}}}}]' \
    > "$FAKE_GH_ATTESTATIONS/$(digest_of "$T/backend.tgz").json"
}

verify() {
  FAKE_GH_LOG="$T/gh.log" bash "$SCRIPTS/verify-provenance.sh" --artifact "$T/backend.tgz" --repo "$REPO" --signer-workflow "$SIGNER" > "$T/out.log" 2>&1
}

prepare() {
  export FAKE_GH_ATTESTATIONS="$T/attestations"
  printf 'bundle\n' > "$T/backend.tgz"
}

test_approved_workflow_passes() {
  prepare; attest "$SIGNER" refs/heads/main github-hosted
  verify
  assert_eq "an attestation from the approved workflow on main passes" 0 $?
  assert_eq "the signer workflow and ref are pinned on the gh call" 1 \
    "$(grep -c -- "--signer-workflow $REPO/$SIGNER --source-ref refs/heads/main --deny-self-hosted-runners" "$T/gh.log")"
}

test_missing_attestation_fails() {
  prepare
  verify
  assert_ne "an artifact without attestation fails" 0 $?
}

test_unapproved_workflow_fails() {
  prepare; attest .github/workflows/other.yml refs/heads/main github-hosted
  verify
  assert_ne "an attestation from an unapproved workflow fails" 0 $?
}

test_branch_build_fails() {
  prepare; attest "$SIGNER" refs/heads/feature github-hosted
  verify
  assert_ne "an attestation from a branch other than main fails" 0 $?
}

test_self_hosted_build_fails() {
  prepare; attest "$SIGNER" refs/heads/main self-hosted
  verify
  assert_ne "an attestation from a self-hosted runner fails" 0 $?
}

run_tests test_approved_workflow_passes test_missing_attestation_fails test_unapproved_workflow_fails test_branch_build_fails test_self_hosted_build_fails
