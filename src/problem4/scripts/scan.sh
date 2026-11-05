#!/usr/bin/env bash
set -uo pipefail

GITLEAKS_IMAGE="zricethezav/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f"
TRIVY_IMAGE="aquasec/trivy:0.76.1@sha256:790fd66d1697395d8693d1acaa1ea702406a20f109b6fc7bac8db623eca6c06c"

root="$(cd "$(dirname "$0")/.." && pwd)"
repo="$(git -C "$root" rev-parse --show-toplevel)"
status=0

echo "== gitleaks over the git history"
docker run --rm -v "$repo:/repo:ro" "$GITLEAKS_IMAGE" git /repo --redact --no-banner --exit-code 1 || status=1

echo "== trivy fs"
docker run --rm -v "$root:/src:ro" -e TRIVY_NO_PROGRESS=true "$TRIVY_IMAGE" fs --scanners vuln,secret,misconfig --include-dev-deps \
  --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --skip-dirs node_modules --skip-dirs dist /src || status=1

exit "$status"
