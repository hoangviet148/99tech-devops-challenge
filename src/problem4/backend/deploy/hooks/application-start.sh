#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

systemctl enable "$SERVICE" > /dev/null
systemctl restart "$SERVICE"
log "started $SERVICE"
