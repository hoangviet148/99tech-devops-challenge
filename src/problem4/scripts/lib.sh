#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }
die() { log "error: $*"; exit 1; }

aws_call() {
  if [ "$DRY_RUN" = "1" ]; then
    printf 'dry-run: aws' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    printf '{}\n'
    return 0
  fi
  aws "$@"
}

sha256_file() {
  if command -v sha256sum > /dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

utc_stamp() { python3 -I -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ"))'; }

hex_to_b64() { python3 -I -c 'import base64, sys; print(base64.b64encode(bytes.fromhex(sys.argv[1])).decode())' "$1"; }

content_type_for() {
  case "$1" in
    *.html) echo "text/html; charset=utf-8" ;;
    *.js) echo "text/javascript; charset=utf-8" ;;
    *.css) echo "text/css; charset=utf-8" ;;
    *.json) echo "application/json" ;;
    *.svg) echo "image/svg+xml" ;;
    *.png) echo "image/png" ;;
    *.ico) echo "image/x-icon" ;;
    *.woff2) echo "font/woff2" ;;
    *) echo "application/octet-stream" ;;
  esac
}

put_immutable() {
  local bucket="$1" key="$2" file="$3" cache="$4" local_b64 existing err
  local_b64="$(hex_to_b64 "$(sha256_file "$file")")"
  err="$(mktemp)"
  if aws_call s3api put-object --bucket "$bucket" --key "$key" --body "$file" --if-none-match '*' \
    --checksum-algorithm SHA256 --cache-control "$cache" --content-type "$(content_type_for "$key")" > /dev/null 2> "$err"; then
    rm -f "$err"
    return 0
  fi
  if ! grep -q 'PreconditionFailed' "$err"; then cat "$err" >&2; rm -f "$err"; die "upload of $key failed"; fi
  rm -f "$err"
  existing="$(aws_call s3api head-object --bucket "$bucket" --key "$key" --checksum-mode ENABLED | jq -r '.ChecksumSHA256 // empty')"
  [ "$existing" = "$local_b64" ] || die "$key already exists with different content"
}

http_get() {
  local url="$1" out="$2"
  curl -sS -m 10 -o "$out" -w '%{http_code} %{content_type}' "$url" 2> /dev/null || printf '000 none'
}

list_keys() {
  aws_call s3api list-objects-v2 --bucket "$1" --prefix "$2" | jq -r '[.Contents[]?.Key] | sort | .[]'
}

read_json() {
  local bucket="$1" key="$2" out
  out="$(mktemp)"
  if [ "$DRY_RUN" = "1" ]; then echo '{}'; rm -f "$out"; return 0; fi
  aws_call s3api get-object --bucket "$bucket" --key "$key" "$out" > /dev/null || { rm -f "$out"; return 1; }
  cat "$out"
  rm -f "$out"
}

require_build_record() {
  local manifest="$1" app="$2" sha="$3" digest="$4" version="${5:-}" record
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: would require builds/$app/$sha.json with digest $digest"
    return 0
  fi
  record="$(read_json "$manifest" "builds/$app/$sha.json")" || die "no build record builds/$app/$sha.json in $manifest"
  [ "$(printf '%s' "$record" | jq -r '.digest // empty')" = "$digest" ] || die "the build record of $app $sha names another digest"
  [ -z "$version" ] || [ "$(printf '%s' "$record" | jq -r '.version_id // empty')" = "$version" ] ||
    die "the build record of $app $sha names another S3 object version"
  log "build record of $app $sha matches digest $digest"
}

require_staging_record() {
  local manifest="$1" app="$2" digest="$3" key
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run: would require a staging deploy record of $app with digest $digest"
    return 0
  fi
  for key in $(list_keys "$manifest" "staging/$app/"); do
    if read_json "$manifest" "$key" | jq -e --arg d "$digest" '.digest == $d and .kind == "deploy"' > /dev/null; then
      log "staging deployed digest $digest in $key"
      return 0
    fi
  done
  die "no staging deploy record of $app with digest $digest"
}
