#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$(cd "$HERE/.." && pwd)"
# shellcheck source=assert.sh
. "$HERE/assert.sh"
export PATH="$HERE/bin:$PATH"

commit() {
  git -C "$T/repo" -c user.name=test -c user.email=test@example.invalid commit -q --allow-empty -m "$1"
  git -C "$T/repo" rev-parse HEAD
}

history() {
  git init -q "$T/repo"
  C1="$(commit one)"
  C2="$(commit two)"
  C3="$(commit three)"
  git -C "$T/repo" checkout -q -b side "$C1"
  SIDE="$(commit side)"
  git -C "$T/repo" checkout -q -
}

deployed() {
  printf '{"sha":"%s","kind":"deploy"}\n' "$1" > "$T/record.json"
  aws s3api put-object --bucket manifest --key "staging/backend/20261104T000000.000000Z-$1.json" --body "$T/record.json" > /dev/null
}

check() { (cd "$T/repo" && bash "$SCRIPTS/check-forward.sh" --app backend --env staging --manifest-bucket manifest "$@") > "$T/out.log" 2>&1; }

test_descendant_passes() {
  history; deployed "$C2"
  check --sha "$C3"
  assert_eq "a descendant of the deployed release passes" 0 $?
}

test_ancestor_is_refused() {
  history; deployed "$C2"
  check --sha "$C1"
  assert_ne "an ancestor of the deployed release is refused" 0 $?
}

test_ancestor_passes_as_rollback() {
  history; deployed "$C2"
  check --sha "$C1" --rollback
  assert_eq "a rollback to an ancestor passes" 0 $?
}

test_same_release_passes() {
  history; deployed "$C2"
  check --sha "$C2"
  assert_eq "a redeploy of the deployed release passes" 0 $?
}

test_diverged_history_is_refused() {
  history; deployed "$C2"
  check --sha "$SIDE"
  assert_ne "a commit off the deployed line is refused" 0 $?
}

test_unknown_deployed_commit_is_refused() {
  history; deployed 1234567890abcdef1234567890abcdef12345678
  check --sha "$C3"
  assert_ne "a deployed commit missing from the checkout is refused" 0 $?
}

test_first_release_passes() {
  history
  check --sha "$C1"
  assert_eq "the first release of an environment passes" 0 $?
}

test_dry_run_makes_no_aws_call() {
  history
  check --sha "$C1" --dry-run
  assert_eq "a dry run passes" 0 $?
  assert_eq "a dry run makes no AWS call" 0 "$(wc -l < "$FAKE_AWS_LOG" | tr -d ' ')"
}

run_tests test_descendant_passes test_ancestor_is_refused test_ancestor_passes_as_rollback test_same_release_passes \
  test_diverged_history_is_refused test_unknown_deployed_commit_is_refused test_first_release_passes test_dry_run_makes_no_aws_call
