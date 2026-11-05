#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

app=""
sha=""
dir=""
bucket=""
manifest_bucket=""
while [ $# -gt 0 ]; do
  case "$1" in
    --app) app="${2:-}"; shift 2 ;;
    --sha) sha="${2:-}"; shift 2 ;;
    --dir) dir="${2:-}"; shift 2 ;;
    --bucket) bucket="${2:-}"; shift 2 ;;
    --manifest-bucket) manifest_bucket="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Usage: publish-artifact.sh --app APP --sha SHA --dir DIR --bucket BUCKET --manifest-bucket BUCKET [--dry-run]" >&2; exit 2 ;;
  esac
done
case "$app" in backend|frontend) ;; *) die "--app must be backend or frontend" ;; esac
[ -f "$dir/$app-$sha.tgz" ] && [ -f "$dir/$app-$sha.build.json" ] || die "build output for $app $sha is missing in $dir"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

put_immutable "$bucket" "$app/$sha.tgz" "$dir/$app-$sha.tgz" "no-cache"
version_id="dry-run"
if [ "$DRY_RUN" != "1" ]; then
  version_id="$(aws_call s3api head-object --bucket "$bucket" --key "$app/$sha.tgz" | jq -r '.VersionId // empty')"
  [ -n "$version_id" ] && [ "$version_id" != "null" ] || die "$bucket returned no VersionId for $app/$sha.tgz, versioning must be on"
fi
if [ "$app" = "backend" ]; then put_immutable "$bucket" "backend/$sha.version.json" "$dir/backend-$sha.version.json" "no-cache"; fi
jq --arg v "$version_id" '. + {version_id: $v}' "$dir/$app-$sha.build.json" > "$work/build.json"

existing=""
[ "$DRY_RUN" = "1" ] || existing="$(read_json "$manifest_bucket" "builds/$app/$sha.json" 2> /dev/null || true)"
if [ -n "$existing" ]; then
  [ "$(printf '%s' "$existing" | jq -r '.digest')" = "$(jq -r '.digest' "$work/build.json")" ] &&
    [ "$(printf '%s' "$existing" | jq -r '.version_id')" = "$version_id" ] ||
    die "builds/$app/$sha.json already records another digest or object version"
  log "build record of $app $sha is already present with the same digest and version"
else
  put_immutable "$manifest_bucket" "builds/$app/$sha.json" "$work/build.json" "no-cache"
fi
log "published $app $sha (object version $version_id)"
