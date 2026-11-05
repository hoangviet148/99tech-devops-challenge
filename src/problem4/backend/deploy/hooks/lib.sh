#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

BACKEND_ROOT="${BACKEND_ROOT:-/opt/backend}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
SERVICE="backend.service"
KEEP_RELEASES="${KEEP_RELEASES:-5}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:8080}"
NODE_BIN="${NODE_BIN:-/opt/node/bin/node}"

release_sha() {
  sed -n 's/.*"sha"[[:space:]]*:[[:space:]]*"\([0-9a-f]\{7,40\}\)".*/\1/p' "$1"
}

release_node_version() {
  sed -n 's/.*"node_version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$1"
}

log() { printf 'backend-hook %s\n' "$*"; }
