#!/usr/bin/env bash
set -euo pipefail

usage() { echo "Usage: summary.sh --app APP --env ENV --sha SHA --status STATUS [--digest HEX] [--url URL]" >&2; }

app=""
env_name=""
sha=""
status=""
digest="n/a"
url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-local}/actions/runs/${GITHUB_RUN_ID:-0}"
while [ $# -gt 0 ]; do
  case "$1" in
    --app) app="${2:-}"; shift 2 ;;
    --env) env_name="${2:-}"; shift 2 ;;
    --sha) sha="${2:-}"; shift 2 ;;
    --status) status="${2:-}"; shift 2 ;;
    --digest) digest="${2:-}"; shift 2 ;;
    --url) url="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[ -n "$app" ] && [ -n "$env_name" ] && [ -n "$sha" ] && [ -n "$status" ] || { usage; exit 2; }

{
  echo "### $app to $env_name: $status"
  echo
  echo "| Field | Value |"
  echo "|---|---|"
  echo "| Release | \`$sha\` |"
  echo "| Artifact digest | \`$digest\` |"
  echo "| Run | $url |"
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"

if [ "$status" != "success" ] && [ -n "${NOTIFY_WEBHOOK_URL:-}" ]; then
  payload="$(jq -n --arg text "$app to $env_name finished with $status for $sha: $url" '{text: $text}')"
  curl -sS -m 10 -X POST -H 'Content-Type: application/json' -d "$payload" "$NOTIFY_WEBHOOK_URL" > /dev/null
fi
