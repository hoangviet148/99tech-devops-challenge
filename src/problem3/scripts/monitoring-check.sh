#!/usr/bin/env bash
set -euo pipefail

usage() { echo "Usage: monitoring-check.sh --yes [--out FILE]" >&2; }

yes=0
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) yes=1; shift ;;
    --out) out="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[ "$yes" -eq 1 ] || { usage; echo "starts the monitoring profile and stops nginx, pass --yes to run" >&2; exit 2; }

here="$(cd "$(dirname "$0")/.." && pwd)"
[ -n "$out" ] || out="$here/evidence/monitoring-check-$(date +%Y%m%d-%H%M%S).md"
prom="http://127.0.0.1:9090"
c() { docker compose -p p3mon --project-directory "$here" -f "$here/docker-compose.yml" -f "$here/tests/compose.verify.yml" --profile monitoring "$@"; }
cleanup() { c down -v --remove-orphans > /dev/null 2>&1 || true; }
trap cleanup EXIT
now_ms() { perl -MTime::HiRes=time -e 'printf("%d\n", time() * 1000)'; }

wait_for() {
  local query="$1" want="$2" limit="$3" start
  start="$(now_ms)"
  while [ $(( $(now_ms) - start )) -lt "$limit" ]; do
    if [ "$(curl -s -m 2 "$prom/api/v1/$query" | jq -r "$want" 2> /dev/null)" = "true" ]; then
      echo $(( $(now_ms) - start ))
      return 0
    fi
    sleep 1
  done
  return 1
}

cleanup
c up -d --build --wait --wait-timeout 180 > /dev/null
targets="$(wait_for targets '[.data.activeTargets[] | select(.health == "up")] | length == 3' 90000)" || { echo "targets did not come up" >&2; exit 1; }
api_id="$(c ps -q api | head -n 1)"
series="$(docker exec "$api_id" wget -qO- http://127.0.0.1:3000/metrics | grep -c '^http_request_duration_seconds_bucket' || true)"
rules="$(curl -s "$prom/api/v1/rules" | jq '[.data.groups[].rules[]] | length')"
c stop nginx > /dev/null
fire="$(wait_for alerts '[.data.alerts[] | select(.labels.alertname == "ApiProbeFailing" and .state == "firing")] | length > 0' 120000)" ||
  { echo "ApiProbeFailing did not fire within 120 s" >&2; exit 1; }
c start nginx > /dev/null
clear="$(wait_for alerts '[.data.alerts[] | select(.labels.alertname == "ApiProbeFailing")] | length == 0' 120000)" ||
  { echo "ApiProbeFailing did not clear within 120 s" >&2; exit 1; }

{
  echo "# Monitoring check"
  echo
  echo "| Field | Value |"
  echo "|---|---|"
  echo "| Stack | \`src/problem3\` at commit \`$(git -C "$here" rev-parse --short HEAD)\` |"
  echo "| Scrape targets up | 3 (two API replicas and the probe) after $targets ms |"
  echo "| Histogram bucket series on one replica | $series |"
  echo "| Alert rules loaded | $rules |"
  echo "| ApiProbeFailing firing after nginx stopped | $fire ms |"
  echo "| ApiProbeFailing cleared after nginx started | $clear ms |"
} > "$out"
echo "results written to $out"
