#!/usr/bin/env bash
set -euo pipefail

needs="${1:-${NEEDS_JSON:-}}"
[ -n "$needs" ] || { echo "usage: ci-gate.sh '<toJSON(needs)>'" >&2; exit 2; }
printf '%s' "$needs" | jq -e 'type == "object"' > /dev/null 2>&1 || { echo "ci-gate: input is not a JSON object" >&2; exit 2; }

bad="$(printf '%s' "$needs" | jq -r 'to_entries[] | select(.value.result != "success" and .value.result != "skipped") | "\(.key)=\(.value.result)"')"
summary="$(printf '%s' "$needs" | jq -r 'to_entries | map("\(.key)=\(.value.result)") | join(" ")')"
if [ -n "$bad" ]; then
  echo "ci-gate: failing because of $(echo "$bad" | tr '\n' ' ')" >&2
  exit 1
fi
echo "ci-gate: passed ($summary)"
