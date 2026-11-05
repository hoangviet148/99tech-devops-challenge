#!/usr/bin/env bash
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
failed=""
for suite in "$here"/test-*.sh; do
  name="$(basename "$suite" .sh)"
  printf '== %s\n' "$name"
  bash "$suite" || failed="$failed $name"
done
if [ -n "$failed" ]; then
  printf 'failed suites:%s\n' "$failed"
  exit 1
fi
echo "all suites passed"
