#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

rm -rf "$BACKEND_ROOT/incoming"
mkdir -p "$BACKEND_ROOT/incoming" "$BACKEND_ROOT/releases"
log "prepared $BACKEND_ROOT/incoming"
