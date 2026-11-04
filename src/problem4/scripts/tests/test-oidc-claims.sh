#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
# shellcheck source=assert.sh
. "$HERE/assert.sh"
export PATH="$HERE/bin:$PATH"

b64url() { printf '%s' "$1" | base64 | tr -d '=\n' | tr '/+' '_-'; }

token_for() {
  printf '%s.%s.signature' "$(b64url '{"alg":"RS256"}')" "$(b64url "$1")"
}

claims() {
  ACTIONS_ID_TOKEN_REQUEST_URL="https://oidc.test/token?api-version=2.0" ACTIONS_ID_TOKEN_REQUEST_TOKEN=request-token \
    bash "$SCRIPTS/oidc-claims.sh" "$@" > "$T/out.log" 2>&1
}

SUB='repo:conbosua@1/ship-it-twice@2:environment:backend-staging:job_workflow_ref:conbosua/ship-it-twice/.github/workflows/_deploy-backend.yml@refs/heads/main'

test_matching_subject_passes() {
  FAKE_OIDC_TOKEN="$(token_for "{\"sub\":\"$SUB\",\"aud\":\"sts.amazonaws.com\"}")" claims --expect-sub "$SUB"
  assert_eq "a matching subject passes" 0 $?
}

test_other_subject_fails() {
  FAKE_OIDC_TOKEN="$(token_for '{"sub":"repo:someone/else:ref:refs/heads/main","aud":"sts.amazonaws.com"}')" claims --expect-sub "$SUB"
  assert_ne "a different subject fails" 0 $?
}

test_other_audience_fails() {
  FAKE_OIDC_TOKEN="$(token_for "{\"sub\":\"$SUB\",\"aud\":\"https://github.com/conbosua\"}")" claims --expect-sub "$SUB"
  assert_ne "a different audience fails" 0 $?
}

test_token_is_never_printed() {
  local token
  token="$(token_for "{\"sub\":\"$SUB\",\"aud\":\"sts.amazonaws.com\"}")"
  FAKE_OIDC_TOKEN="$token" claims --expect-sub "$SUB"
  assert_eq "the raw token only appears in the masking command" 1 "$(grep -cF -- "$token" "$T/out.log")"
  assert_eq "the masking command precedes any output" 1 "$(grep -c '^::add-mask::' "$T/out.log")"
}

test_missing_endpoint_fails() {
  bash "$SCRIPTS/oidc-claims.sh" > "$T/out.log" 2>&1
  assert_ne "a job without id-token permission fails" 0 $?
}

test_unpinned_subject_passes_without_aws() {
  FAKE_OIDC_TOKEN="$(token_for "{\"sub\":\"$SUB\",\"aud\":\"sts.amazonaws.com\"}")" claims
  assert_eq "an unpinned subject only prints the claims while no AWS access follows" 0 $?
}

test_unpinned_subject_fails_before_aws() {
  FAKE_OIDC_TOKEN="$(token_for "{\"sub\":\"$SUB\",\"aud\":\"sts.amazonaws.com\"}")" claims --require-sub
  assert_ne "an unpinned subject fails when AWS access follows" 0 $?
}

run_tests test_unpinned_subject_passes_without_aws test_unpinned_subject_fails_before_aws test_matching_subject_passes test_other_subject_fails test_other_audience_fails test_token_is_never_printed test_missing_endpoint_fails
