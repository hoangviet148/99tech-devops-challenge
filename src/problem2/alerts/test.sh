#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_IMAGE="prom/prometheus:v3.15.1@sha256:fa3302279710be2f21a8301ec17a8b4f2301fd829bd113839b3b6b02b6f191a2"

here="$(cd "$(dirname "$0")" && pwd)"
promtool() { docker run --rm --entrypoint /bin/promtool -v "$here:/rules:ro" -w /rules "$PROMETHEUS_IMAGE" "$@"; }

promtool check rules disk-rules.yml
promtool test rules disk-rules.test.yml
