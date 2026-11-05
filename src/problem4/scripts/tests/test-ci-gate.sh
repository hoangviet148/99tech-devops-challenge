#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
# shellcheck source=assert.sh
. "$HERE/assert.sh"

gate() { bash "$SCRIPTS/ci-gate.sh" "$1" > "$T/out.log" 2>&1; echo $?; }

test_results() {
  assert_eq "all jobs succeeded" 0 "$(gate '{"backend":{"result":"success"},"frontend":{"result":"success"}}')"
  assert_eq "a skipped path-filtered job passes" 0 "$(gate '{"backend":{"result":"success"},"frontend":{"result":"skipped"}}')"
  assert_eq "a failed job fails the gate" 1 "$(gate '{"backend":{"result":"failure"},"frontend":{"result":"success"}}')"
  assert_eq "a cancelled job fails the gate" 1 "$(gate '{"backend":{"result":"cancelled"},"frontend":{"result":"success"}}')"
  assert_eq "invalid input is rejected" 2 "$(gate 'not json')"
}

run_tests test_results
