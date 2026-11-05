#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
scripts="$(cd "$here/../.." && pwd)"
root="$(cd "$scripts/.." && pwd)"
work="$(mktemp -d)"
server=""
cleanup() {
  [ -z "$server" ] || kill "$server" 2> /dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

real_curl="$(command -v curl)"
export SOURCE_DATE_EPOCH=1793750400 RELEASE_A=aaaaaaa RELEASE_B=bbbbbbb
(cd "$root/frontend" && npm ci --no-audit --no-fund > /dev/null)
bash "$scripts/build-frontend.sh" --sha "$RELEASE_A" --out "$work/out" --skip-install
bash "$scripts/build-frontend.sh" --sha "$RELEASE_B" --out "$work/out" --skip-install
export ARTIFACT_B="$work/out/frontend-$RELEASE_B.tgz"

export PATH="$here/../bin:$PATH" FAKE_AWS_STATE="$work/state" FAKE_AWS_LOG="$work/aws.log" FAKE_CURL_LOG="$work/curl.log"
export FAKE_FRONTEND_BUCKET=frontend-bucket FAKE_BACKEND_API=1 FAKE_BACKEND_SHA=unknown
mkdir -p "$FAKE_AWS_STATE"
DEPLOY_ARGS="$(jq -cn --arg s "$scripts/deploy-frontend.sh" '[$s, "--env", "local", "--bucket", "frontend-bucket", "--distribution", "ELOCAL",
  "--manifest-bucket", "manifest-bucket", "--base-url", "http://frontend.test", "--backend-url", "http://backend.test"]')"
export DEPLOY_ARGS
bash "$scripts/deploy-frontend.sh" --env local --bucket frontend-bucket --distribution ELOCAL --manifest-bucket manifest-bucket \
  --base-url http://frontend.test --backend-url http://backend.test --sha "$RELEASE_A" --artifact "$work/out/frontend-$RELEASE_A.tgz"

cd "$here"
npm ci --no-audit --no-fund > /dev/null
npx playwright install ${PLAYWRIGHT_WITH_DEPS:+--with-deps} chromium > /dev/null
api_origin="$(jq -r .apiBaseUrl "$root/frontend/config/local.json")"
csp="$(sed "s#<API_ORIGIN>#$api_origin#" "$root/infra/policies/content-security-policy.txt")"
BUCKET_DIR="$FAKE_AWS_STATE/s3/frontend-bucket" CONTENT_SECURITY_POLICY="$csp" node server.mjs &
server=$!
for _ in $(seq 1 50); do "$real_curl" -fs -o /dev/null http://127.0.0.1:4173/ && break; sleep 0.2; done
"$real_curl" -fs -o /dev/null http://127.0.0.1:4173/ || { echo "the static server did not start" >&2; exit 1; }
npx playwright test
