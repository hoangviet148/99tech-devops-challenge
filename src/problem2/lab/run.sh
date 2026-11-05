#!/usr/bin/env bash
set -euo pipefail

IMAGE="ubuntu:noble-20260930.1@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac"

usage() { echo "Usage: run.sh --yes [--out FILE]" >&2; }

yes=0
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --yes) yes=1; shift ;;
    --out) out="${2:-}"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
if [ "$yes" -ne 1 ]; then
  usage
  echo "The lab starts a privileged container that attaches two loop devices in the Docker VM. Pass --yes to run it." >&2
  exit 2
fi
command -v docker > /dev/null || { echo "docker is required" >&2; exit 2; }

here="$(cd "$(dirname "$0")" && pwd)"
[ -n "$out" ] || out="$(cd "$here/.." && pwd)/evidence/lab-$(date -u +%Y%m%dT%H%M%SZ).md"
mkdir -p "$(dirname "$out")"
partial="$out.partial"

if docker run --rm --privileged -e LAB_IMAGE="$IMAGE" -v "$here:/lab:ro" "$IMAGE" bash /lab/inside.sh > "$partial"; then
  mv "$partial" "$out"
  echo "lab results written to $out"
else
  echo "the lab failed, partial output kept in $partial" >&2
  exit 1
fi
