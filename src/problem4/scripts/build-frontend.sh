#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

usage() { echo "Usage: build-frontend.sh --sha SHA --out DIR [--skip-install]" >&2; }

sha=""
out=""
install=1
while [ $# -gt 0 ]; do
  case "$1" in
    --sha) sha="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    --skip-install) install=0; shift ;;
    *) usage; exit 2 ;;
  esac
done
[ -n "$sha" ] && [ -n "$out" ] || { usage; exit 2; }
printf '%s' "$sha" | grep -Eq '^[0-9a-f]{7,40}$' || die "--sha must be a hex commit SHA"

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/frontend"
if [ -n "${SOURCE_DATE_EPOCH:-}" ]; then
  epoch="$SOURCE_DATE_EPOCH"
else
  epoch="$(git -C "$root" log -1 --format=%ct "$sha" 2> /dev/null)" || die "commit $sha is not in this checkout"
fi
printf '%s' "$epoch" | grep -Eq '^[0-9]+$' || die "the source date must be a Unix timestamp"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

if [ "$install" -eq 1 ]; then (cd "$app" && npm ci --no-audit --no-fund); fi
(cd "$app" && rm -rf dist && VITE_RELEASE_SHA="$sha" npm run build)
grep -q "name=\"release-sha\" content=\"$sha\"" "$app/dist/index.html" || die "index.html does not carry release $sha"

cp -R "$app/dist" "$stage/dist"
cp -R "$app/config" "$stage/config"
committed_at="$(python3 -I -c 'import datetime, sys; print(datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$epoch")"
jq -n --arg sha "$sha" --arg at "$committed_at" '{sha: $sha, committed_at: $at}' > "$stage/version.json"
jq --arg sha "$sha" '{sha: $sha, min_backend_api: .min_backend_api}' "$app/contract.json" > "$stage/release.json"

artifact="$out/frontend-$sha.tgz"
python3 -I "$root/scripts/pack-tgz.py" "$stage" "$artifact" "$epoch"
digest="$(sha256_file "$artifact")"
printf '%s  %s\n' "$digest" "$(basename "$artifact")" > "$artifact.sha256"
jq -n --arg app frontend --arg sha "$sha" --arg digest "$digest" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg workflow "${GITHUB_WORKFLOW_REF:-local}" --arg run "${GITHUB_RUN_ID:-local}" \
  '{app: $app, sha: $sha, digest: $digest, built_at: $at, workflow_ref: $workflow, run_id: $run}' > "$out/frontend-$sha.build.json"
log "built $artifact ($digest)"
