#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

if systemctl list-unit-files "$SERVICE" > /dev/null 2>&1 && systemctl is-active --quiet "$SERVICE"; then
  log "stopping $SERVICE"
  systemctl stop "$SERVICE"
else
  log "$SERVICE is not running, nothing to stop"
fi
