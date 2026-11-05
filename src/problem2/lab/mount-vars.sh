#!/usr/bin/env bash
set -euo pipefail

P="${1:?usage: mount-vars.sh PATH}"
read -r MNT FSTYPE MAJMIN < <(findmnt -n -o TARGET,FSTYPE,MAJ:MIN -T "$P")
DEV="/dev/$(basename "$(readlink -f "/sys/dev/block/$MAJMIN")")"
printf 'MNT=%s DEV=%s FSTYPE=%s\n' "$MNT" "$DEV" "$FSTYPE"
