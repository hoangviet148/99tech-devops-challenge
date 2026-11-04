#!/usr/bin/env bash
# shellcheck disable=SC2034
PASSED=0
FAILED=0
T=""

ok() { PASSED=$((PASSED + 1)); printf 'ok - %s\n' "$1"; }
not_ok() {
  FAILED=$((FAILED + 1))
  printf 'not ok - %s\n' "$1"
  [ -n "${2:-}" ] && printf '#   %s\n' "$2"
  if [ -f "$T/out.log" ]; then sed 's/^/#   | /' "$T/out.log" | tail -n 8; fi
  return 0
}

assert_eq() { if [ "$2" = "$3" ]; then ok "$1"; else not_ok "$1" "expected '$2', got '$3'"; fi; }
assert_ne() { if [ "$2" != "$3" ]; then ok "$1"; else not_ok "$1" "expected anything but '$2'"; fi; }
assert_logged() { if grep -qF -- "$2" "$FAKE_AWS_LOG"; then ok "$1"; else not_ok "$1" "no call matching '$2'"; fi; }
assert_not_logged() { if grep -qF -- "$2" "$FAKE_AWS_LOG"; then not_ok "$1" "unexpected call matching '$2'"; else ok "$1"; fi; }
assert_before() {
  local first second
  first="$(grep -nF -- "$2" "$FAKE_AWS_LOG" | head -n 1 | cut -d: -f1)"
  second="$(grep -nF -- "$3" "$FAKE_AWS_LOG" | head -n 1 | cut -d: -f1)"
  if [ -n "$first" ] && [ -n "$second" ] && [ "$first" -lt "$second" ]; then ok "$1"; else not_ok "$1" "'$2' at line ${first:-none}, '$3' at line ${second:-none}"; fi
}

setup() {
  T="$(mktemp -d)"
  export FAKE_AWS_STATE="$T/state" FAKE_AWS_LOG="$T/aws.log" FAKE_CURL_LOG="$T/curl.log"
  mkdir -p "$FAKE_AWS_STATE"
  : > "$FAKE_AWS_LOG"
  unset FAKE_AWS_FAIL FAKE_INVALIDATION_WAIT FAKE_DEPLOY_WAIT FAKE_TARGET_STATUSES FAKE_TARGET_HEALTH FAKE_BACKEND_HEALTH FAKE_ALARM_STATES
  export FAKE_BACKEND_API=1 FAKE_BACKEND_SHA=unknown
}

run_tests() {
  local t
  for t in "$@"; do
    setup
    printf '# %s\n' "$t"
    "$t"
    rm -rf "$T"
  done
  printf '# passed %s, failed %s\n' "$PASSED" "$FAILED"
  [ "$FAILED" -eq 0 ]
}
