#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

incoming="$BACKEND_ROOT/incoming"
sha="$(release_sha "$incoming/version.json")"
[ -n "$sha" ] || { log "no release SHA in $incoming/version.json"; exit 1; }
target="$BACKEND_ROOT/releases/$sha"
rm -rf "$target"
mv "$incoming" "$target"
ln -sfn "$target" "$BACKEND_ROOT/current.next"
mv -T "$BACKEND_ROOT/current.next" "$BACKEND_ROOT/current"
install -m 0644 "$target/deploy/backend.service" "$SYSTEMD_DIR/$SERVICE"
systemctl daemon-reload
for dir in "$BACKEND_ROOT"/releases/*/; do
  printf '%s %s\n' "$(stat -c %Y "$dir")" "${dir%/}"
done | sort -rn | tail -n +$((KEEP_RELEASES + 1)) | cut -d' ' -f2- |
  while read -r old; do
    [ "$old" = "$target" ] || rm -rf "$old"
  done
log "release $sha installed"
