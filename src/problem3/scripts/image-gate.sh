#!/usr/bin/env bash
set -euo pipefail

TRIVY_IMAGE="aquasec/trivy:0.76.1@sha256:790fd66d1697395d8693d1acaa1ea702406a20f109b6fc7bac8db623eca6c06c"
HADOLINT_IMAGE="hadolint/hadolint:v2.15.1@sha256:32dac94127fd60b7b7e3fbfc65e1383b9b5e25c9bfd7b8536de7a539fe68a12d"

usage() { echo "Usage: image-gate.sh --yes [--before-ref REF] [--out FILE]" >&2; }

yes=0
ref="${P3_BEFORE_REF:-upstream/main}"
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) yes=1; shift ;;
    --before-ref) ref="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[ "$yes" -eq 1 ] || { usage; echo "builds images and pulls scanners, pass --yes to run" >&2; exit 2; }

here="$(cd "$(dirname "$0")/.." && pwd)"
repo="$(git -C "$here" rev-parse --show-toplevel)"
[ -n "$out" ] || out="$here/evidence/image-gate-$(date +%Y%m%d-%H%M%S).md"
wt="$(mktemp -d "${TMPDIR:-/tmp}/p3gate.XXXXXX")"
git -C "$repo" worktree add --detach "$wt" "$ref" > /dev/null
trap 'git -C "$repo" worktree remove --force "$wt" > /dev/null 2>&1 || true' EXIT

images_of() {
  docker compose --project-directory "$1" -f "$1/docker-compose.yml" config --format json 2> /dev/null |
    jq -r '.services[] | select(.build == null) | .image'
}

docker build -q -t p3gate-api:before "$wt/src/problem3/api" > /dev/null
docker build -q -t p3gate-api:after "$here/api" > /dev/null

counts() {
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v p3gate-trivy-cache:/root/.cache "$TRIVY_IMAGE" image --quiet \
    --scanners vuln --severity HIGH,CRITICAL --format json "$1" |
    jq -r '[.Results[]?.Vulnerabilities[]?] | [(map(select(.Severity == "HIGH")) | length), (map(select(.Severity == "CRITICAL")) | length),
      (map(select(.FixedVersion != null and .FixedVersion != "")) | length)] | @tsv'
}

lint() {
  local n
  n="$(docker run --rm -i "$HADOLINT_IMAGE" hadolint --no-fail --format json - < "$1" | jq 'length')"
  printf '%s' "$n"
}

{
  echo "# Image gate, before and after"
  echo
  echo "| Field | Value |"
  echo "|---|---|"
  echo "| Before | \`$ref\` at \`$(git -C "$repo" rev-parse --short "$ref")\` |"
  echo "| After | \`src/problem3\` at \`$(git -C "$repo" rev-parse --short HEAD)\` |"
  echo "| Scanner | trivy 0.76.1, HIGH and CRITICAL, database of $(date +%Y-%m-%d) |"
  echo
  echo "| Side | Image | HIGH | CRITICAL | With a fix available |"
  echo "|---|---|---|---|---|"
  for side in before after; do
    if [ "$side" = "before" ]; then dir="$wt/src/problem3"; else dir="$here"; fi
    for image in $(images_of "$dir") "p3gate-api:$side"; do
      row="$(counts "$image")" || { echo "trivy failed on $image" >&2; exit 1; }
      IFS="$(printf '\t')" read -r high critical fixable <<< "$row"
      echo "| $side | \`$image\` | $high | $critical | $fixable |"
    done
  done
  echo
  echo "| Side | Dockerfile | hadolint findings |"
  echo "|---|---|---|"
  echo "| before | \`api/Dockerfile\` | $(lint "$wt/src/problem3/api/Dockerfile") |"
  echo "| after | \`api/Dockerfile\` | $(lint "$here/api/Dockerfile") |"
} > "$out"
echo "results written to $out"
