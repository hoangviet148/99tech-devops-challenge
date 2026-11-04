#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_IMAGE="prom/prometheus:v3.15.1@sha256:fa3302279710be2f21a8301ec17a8b4f2301fd829bd113839b3b6b02b6f191a2"

here="$(cd "$(dirname "$0")/.." && pwd)"
docker run --rm -v "$here/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro" -v "$here/monitoring/rules:/etc/prometheus/rules:ro" \
  --entrypoint promtool "$PROMETHEUS_IMAGE" check config /etc/prometheus/prometheus.yml
docker run --rm -v "$here/monitoring:/m:ro" --entrypoint promtool "$PROMETHEUS_IMAGE" test rules /m/tests/api.test.yml
