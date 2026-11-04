#!/usr/bin/env bash
set -uo pipefail

ACTIONLINT_IMAGE="rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667"
ZIZMOR_IMAGE="ghcr.io/zizmorcore/zizmor:1.31.1@sha256:42d409dbb851d4c5d35a058cf042b828bea1e3f2884378c526eb0974780e18d9"

root="$(cd "$(dirname "$0")/.." && pwd)"
status=0

echo "== actionlint"
docker run --rm -v "$root:/repo:ro" -w /repo "$ACTIONLINT_IMAGE" -color=false || status=1

echo "== zizmor"
zizmor_args=(--min-severity medium --no-progress .github)
if [ -n "${GH_TOKEN:-}" ]; then
  docker run --rm -e GH_TOKEN -v "$root:/repo:ro" -w /repo "$ZIZMOR_IMAGE" "${zizmor_args[@]}" || status=1
else
  docker run --rm -v "$root:/repo:ro" -w /repo "$ZIZMOR_IMAGE" --offline "${zizmor_args[@]}" || status=1
fi

echo "== shellcheck"
(cd "$root" && shellcheck -s bash -x -P SCRIPTDIR scripts/*.sh scripts/tests/*.sh scripts/tests/bin/* scripts/tests/hooks/*.sh \
  scripts/tests/hooks/systemctl backend/deploy/hooks/*.sh) || status=1

exit "$status"
