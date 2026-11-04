#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
REF="${P3_BEFORE_REF:-upstream/main}"
WT="$(mktemp -d "${TMPDIR:-/tmp}/p3before.XXXXXX")"

git -C "$REPO" worktree add --detach "$WT" "$REF" > /dev/null
trap 'git -C "$REPO" worktree remove --force "$WT" > /dev/null 2>&1 || true' EXIT

bash "$SCRIPT_DIR/verify.sh" --profile before --stack-dir "$WT/src/problem3" "$@"
