#!/usr/bin/env bash
set -uo pipefail

HOOKS=/bundle/deploy/hooks
PASSED=0
FAILED=0
ok() { PASSED=$((PASSED + 1)); printf 'ok - %s\n' "$1"; }
not_ok() { FAILED=$((FAILED + 1)); printf 'not ok - %s\n' "$1"; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else not_ok "$1 (expected '$2', got '$3')"; fi; }

deploy() {
  local sha="$1" hook rc=0
  for hook in application-stop before-install; do
    bash "$HOOKS/$hook.sh" > /dev/null || return 1
  done
  cp -R /bundle/. /opt/backend/incoming/
  printf '{\n  "sha": "%s",\n  "committed_at": "2026-11-04T00:00:00Z",\n  "api_version": 1\n}\n' "$sha" > /opt/backend/incoming/version.json
  for hook in after-install application-start validate-service; do
    bash "$HOOKS/$hook.sh" > "/tmp/$hook.log" 2>&1 || { rc=1; break; }
  done
  return "$rc"
}

calls() { grep -c "$1" /run/fake-systemd/calls.log 2> /dev/null || true; }

deploy aaaaaaa
check "the first deployment succeeds without an existing service" 0 $?
check "current points to the first release" /opt/backend/releases/aaaaaaa "$(readlink /opt/backend/current)"
check "the unit file is installed" 1 "$([ -f /etc/systemd/system/backend.service ] && echo 1 || echo 0)"
check "nothing is stopped on the first deployment" 0 "$(calls 'systemctl stop')"

sleep 1
deploy bbbbbbb
check "a redeployment succeeds" 0 $?
check "current points to the second release" /opt/backend/releases/bbbbbbb "$(readlink /opt/backend/current)"
check "the redeployment stops the running service first" 1 "$(calls 'systemctl stop')"
check "the previous release stays on disk" 1 "$([ -d /opt/backend/releases/aaaaaaa ] && echo 1 || echo 0)"

mkdir -p /run/fake-systemd && printf 'ccccccc\n' > /run/fake-systemd/serve-sha
deploy ddddddd
check "validation fails when the service reports another release" 1 $?
check "the failure names both releases" 1 "$(grep -c 'serving ccccccc, expected ddddddd' /tmp/validate-service.log)"
rm -f /run/fake-systemd/serve-sha

for sha in 1111111 2222222 3333333 4444444 5555555 6666666; do
  sleep 1
  deploy "$sha" || not_ok "deployment of $sha"
done
kept=(/opt/backend/releases/*/)
check "only the configured number of releases is kept" 5 "${#kept[@]}"
check "the current release is kept" 1 "$([ -d /opt/backend/releases/6666666 ] && echo 1 || echo 0)"
check "the oldest release is removed" 0 "$([ -d /opt/backend/releases/aaaaaaa ] && echo 1 || echo 0)"

printf '# passed %s, failed %s\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
