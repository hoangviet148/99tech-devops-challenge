#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

BUILD_IMAGE="amazonlinux:2023.12.20261021.0@sha256:c04a1012acc483977f61f7f91c28624a39a621e56a59781319a75dec528be9b6"

usage() { echo "Usage: build-backend.sh --sha SHA --out DIR [--arch x64|arm64]" >&2; }

sha=""
out=""
arch="x64"
while [ $# -gt 0 ]; do
  case "$1" in
    --sha) sha="${2:-}"; shift 2 ;;
    --out) out="${2:-}"; shift 2 ;;
    --arch) arch="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[ -n "$sha" ] && [ -n "$out" ] || { usage; exit 2; }
printf '%s' "$sha" | grep -Eq '^[0-9a-f]{7,40}$' || die "--sha must be a hex commit SHA"
case "$arch" in
  x64) platform="linux/amd64" ;;
  arm64) platform="linux/arm64" ;;
  *) die "--arch must be x64 or arm64" ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/backend"
if [ -n "${SOURCE_DATE_EPOCH:-}" ]; then
  epoch="$SOURCE_DATE_EPOCH"
else
  epoch="$(git -C "$root" log -1 --format=%ct "$sha" 2> /dev/null)" || die "commit $sha is not in this checkout"
fi
printf '%s' "$epoch" | grep -Eq '^[0-9]+$' || die "the source date must be a Unix timestamp"
node_version="$(tr -d '[:space:]' < "$app/.node-version")"
tarball="node-v$node_version-linux-$arch.tar.xz"
expected="$(awk -v f="$tarball" '$2 == f { print $1 }' "$app/node-sha256.txt")"
[ -n "$expected" ] || die "backend/node-sha256.txt has no checksum for $tarball"
api_version="$(awk '$1 == "x-api-version:" { print $2; exit }' "$app/openapi.yaml")"
printf '%s' "$api_version" | grep -Eq '^[0-9]+$' || die "backend/openapi.yaml has no integer x-api-version"

mkdir -p "$out"
out="$(cd "$out" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl -fsSL --retry 3 -o "$work/$tarball" "https://nodejs.org/dist/v$node_version/$tarball"
[ "$(sha256_file "$work/$tarball")" = "$expected" ] || die "checksum mismatch for $tarball"
mkdir -p "$work/node" "$work/src"
tar -xJf "$work/$tarball" -C "$work/node" --strip-components=1
cp -R "$app/package.json" "$app/package-lock.json" "$app/.npmrc" "$app/tsconfig.json" "$app/src" "$work/src/"

docker run --rm --platform "$platform" --user "$(id -u):$(id -g)" --network bridge \
  -e HOME=/tmp -e npm_config_cache=/tmp/.npm -e npm_config_update_notifier=false -e NODE_VERSION="$node_version" \
  -v "$work/node:/opt/node:ro" -v "$work/src:/build" -w /build "$BUILD_IMAGE" /bin/bash -euo pipefail -c '
    export PATH=/opt/node/bin:$PATH
    [ "$(node --version)" = "v$NODE_VERSION" ]
    npm ci --ignore-scripts --no-audit --no-fund
    npm run build
    rm -rf node_modules
    npm ci --omit=dev --ignore-scripts --no-bin-links --no-audit --no-fund'

native=""
[ ! -d "$work/src/node_modules" ] || native="$(find "$work/src/node_modules" \( -name '*.node' -o -name binding.gyp \) -print)"
[ -z "$native" ] || die "production dependencies contain native addons: $native"

bundle="$work/bundle"
mkdir -p "$bundle/deploy"
cp "$app/deploy/appspec.yml" "$bundle/appspec.yml"
cp -R "$work/src/dist" "$bundle/dist"
[ ! -d "$work/src/node_modules" ] || cp -R "$work/src/node_modules" "$bundle/node_modules"
cp "$app/package.json" "$app/package-lock.json" "$bundle/"
cp -R "$app/deploy/hooks" "$bundle/deploy/hooks"
cp "$app/deploy/backend.service" "$bundle/deploy/backend.service"
committed_at="$(python3 -I -c 'import datetime, sys; print(datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))' "$epoch")"
jq -n --arg sha "$sha" --arg at "$committed_at" --argjson api "$api_version" --arg node "$node_version" \
  '{sha: $sha, committed_at: $at, api_version: $api, node_version: $node}' > "$bundle/version.json"

artifact="$out/backend-$sha.tgz"
python3 -I "$root/scripts/pack-tgz.py" "$bundle" "$artifact" "$epoch"
digest="$(sha256_file "$artifact")"
printf '%s  %s\n' "$digest" "$(basename "$artifact")" > "$artifact.sha256"
cp "$bundle/version.json" "$out/backend-$sha.version.json"
jq -n --arg app backend --arg sha "$sha" --arg digest "$digest" --argjson api "$api_version" --arg node "$node_version" \
  --arg image "$BUILD_IMAGE" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg workflow "${GITHUB_WORKFLOW_REF:-local}" --arg run "${GITHUB_RUN_ID:-local}" \
  '{app: $app, sha: $sha, digest: $digest, api_version: $api, node_version: $node, build_image: $image, built_at: $at, workflow_ref: $workflow, run_id: $run}' \
  > "$out/backend-$sha.build.json"
log "built $(basename "$artifact") ($digest)"
