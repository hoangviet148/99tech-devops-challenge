#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
# shellcheck source=assert.sh
. "$HERE/assert.sh"
export PATH="$HERE/bin:$PATH"

run_summary() {
  GITHUB_STEP_SUMMARY="$T/summary.md" bash "$SCRIPTS/summary.sh" --app backend --env production --sha aaaaaaa --digest abc "$@" > "$T/out.log" 2>&1
}

test_summary_without_webhook() {
  unset NOTIFY_WEBHOOK_URL
  run_summary --status failure
  assert_eq "the summary script exits 0" 0 $?
  assert_eq "the summary names the release" 1 "$(grep -c 'aaaaaaa' "$T/summary.md")"
  assert_eq "no notification without a webhook" 0 "$(grep -c '^POST' "$FAKE_CURL_LOG" 2> /dev/null || echo 0)"
}

test_failure_notifies_webhook() {
  NOTIFY_WEBHOOK_URL=https://hooks.test/notify run_summary --status failure
  assert_eq "a failure posts one notification" 1 "$(grep -c '^POST https://hooks.test/notify' "$FAKE_CURL_LOG")"
}

test_success_does_not_notify() {
  NOTIFY_WEBHOOK_URL=https://hooks.test/notify run_summary --status success
  assert_eq "a success posts no notification" 0 "$(grep -c '^POST' "$FAKE_CURL_LOG" 2> /dev/null || echo 0)"
}

run_tests test_summary_without_webhook test_failure_notifies_webhook test_success_does_not_notify
