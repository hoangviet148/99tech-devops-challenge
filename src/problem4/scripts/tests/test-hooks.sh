#!/usr/bin/env bash
set -uo pipefail

IMAGE="amazonlinux:2023.12.20261021.0@sha256:c04a1012acc483977f61f7f91c28624a39a621e56a59781319a75dec528be9b6"

here="$(cd "$(dirname "$0")" && pwd)"
backend="$(cd "$here/../../backend" && pwd)"
docker run --rm --platform linux/amd64 \
  -v "$backend/deploy/hooks:/bundle/deploy/hooks:ro" \
  -v "$backend/deploy/backend.service:/bundle/deploy/backend.service:ro" \
  -v "$here/hooks:/tests/hooks:ro" \
  "$IMAGE" /bin/bash -c 'install -m 0755 /tests/hooks/systemctl /usr/local/bin/systemctl && mkdir -p /etc/systemd/system && bash /tests/hooks/scenario.sh'
