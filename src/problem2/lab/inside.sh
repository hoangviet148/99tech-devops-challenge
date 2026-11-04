#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK=/srv/lab
FS=/mnt/labfs
INODE_FS=/mnt/inodes
LB=http://127.0.0.1:8080
ERROR_LOG=/var/log/lab/error.log
ACCESS_LOG=/var/log/nginx/access.log
LARGE_BYTES=4194304
BODY_BYTES=524288
RATE=512k
RESULTS="$WORK/results.md"
EVIDENCE="$WORK/evidence.md"
RUN_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
NGINX_VERSION="not installed"
LOOP=""
INODE_LOOP=""

mkdir -p "$WORK" "$FS" "$INODE_FS" /var/log/lab /srv/upstream
: > "$RESULTS"
: > "$EVIDENCE"

log() { printf '%s %s\n' "$(date -u +%T)" "$*" >&2; }
section() { printf '\n### %s\n\n%s\n' "$1" "$2" >> "$EVIDENCE"; }
result() { printf '| %s | %s | %s | %s | %s |\n' "$1" "$2" "$3" "$4" "$5" >> "$RESULTS"; }
used() { df -B1 --output=used "$FS" | tail -n 1 | tr -d ' '; }
avail() { df -B1 --output=avail "$FS" | tail -n 1 | tr -d ' '; }
kib() { echo $(($1 / 1024)); }
lines() { if [ -e "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
count() { grep -cF -- "$1" "$ERROR_LOG" || true; }
code_of() { curl -s -m 30 -o /dev/null -w '%{http_code}' "$@" || true; }

show() {
  {
    printf '\n```console\n$ %s\n' "$1"
    bash -c "$1" 2>&1 || printf '(exit status %s)\n' "$?"
    printf '```\n'
  } >> "$EVIDENCE"
}

stop_nginx() {
  if pgrep -x nginx > /dev/null; then
    nginx -s quit 2> /dev/null || pkill -x nginx || true
    for _ in $(seq 1 50); do
      pgrep -x nginx > /dev/null || break
      sleep 0.1
    done
  fi
}

finish() {
  local rc=$?
  stop_nginx
  umount /var/log/nginx 2> /dev/null || true
  umount /var/lib/nginx 2> /dev/null || true
  umount "$FS" 2> /dev/null || true
  umount "$INODE_FS" 2> /dev/null || true
  [ -z "$LOOP" ] || losetup -d "$LOOP" 2> /dev/null || true
  [ -z "$INODE_LOOP" ] || losetup -d "$INODE_LOOP" 2> /dev/null || true
  printf '# Full-disk lab run\n\n| Field | Value |\n|---|---|\n'
  printf '| Run | %s |\n| Image | %s |\n' "$RUN_AT" "\`${LAB_IMAGE:-unknown}\`"
  printf '| Kernel | %s on %s |\n| NGINX | %s |\n' "\`$(uname -r)\`" "$(uname -m)" "\`$NGINX_VERSION\`"
  printf '| Exit status | %s |\n\n' "$rc"
  printf '## Results\n\n| ID | Check | Expected | Observed | Match |\n|---|---|---|---|---|\n'
  cat "$RESULTS"
  printf '\n## Evidence\n'
  cat "$EVIDENCE"
  exit "$rc"
}
trap finish EXIT

log "installing packages"
export DEBIAN_FRONTEND=noninteractive
if ! { apt-get update -qq && apt-get install -y -qq --no-install-recommends nginx logrotate lsof curl e2fsprogs procps; } > "$WORK/apt.log" 2>&1; then
  tail -n 30 "$WORK/apt.log" >&2
  exit 1
fi
stop_nginx
NGINX_VERSION="$(nginx -v 2>&1)"

log "creating the loop-backed ext4 filesystem"
truncate -s 16M "$WORK/disk.img"
mkfs.ext4 -q -F -m 5 -L labfs "$WORK/disk.img"
LOOP="$(losetup --find --show "$WORK/disk.img")" || { echo "no free loop device in this Docker VM" >&2; exit 1; }
mount "$LOOP" "$FS"
for pair in log:/var/log/nginx lib:/var/lib/nginx; do
  sub="${pair%%:*}"
  dir="${pair#*:}"
  mkdir -p "$FS/$sub"
  chown --reference="$dir" "$FS/$sub"
  chmod --reference="$dir" "$FS/$sub"
  mount --bind "$FS/$sub" "$dir"
done
mkdir -p "$FS/fill"
chown www-data "$FS/fill"

log "starting nginx with the lab configuration"
install -m 0644 "$LAB_DIR/nginx.conf" /etc/nginx/nginx.conf
printf 'small response\n' > /srv/upstream/small.txt
head -c "$LARGE_BYTES" /dev/urandom > /srv/upstream/large.bin
head -c "$BODY_BYTES" /dev/urandom > "$WORK/body.bin"
nginx -t > "$WORK/nginx-t.log" 2>&1 || { cat "$WORK/nginx-t.log" >&2; exit 1; }
nginx
for _ in $(seq 1 50); do
  [ "$(code_of "$LB/small.txt")" = 200 ] && break
  sleep 0.1
done
[ "$(code_of "$LB/small.txt")" = 200 ] || { echo "nginx does not answer on $LB" >&2; exit 1; }

section "E0 Filesystem under test" "The runbook derives MNT, DEV and FSTYPE from the path. NGINX logs and temp files share one 16 MiB ext4 filesystem with 5 % reserved for root. The NGINX error log stays outside it so its messages survive the fill."
show "findmnt -n -o TARGET,SOURCE,FSTYPE,MAJ:MIN -T /var/log/nginx"
show "bash $LAB_DIR/mount-vars.sh /var/log/nginx"
show "df -hT $FS"
show "df -i $FS"
show "tune2fs -l $LOOP | grep -E '^(Block count|Reserved block count|Block size)'"
show "nginx -V 2>&1 | tr ' ' '\n' | grep temp-path"
show "ps -o user=,pid=,args= -C nginx"

log "L0 large response to a slow client with free space"
before="$(used)"
curl -s -m 60 -o "$WORK/l0.out" --limit-rate "$RATE" -w '%{http_code} %{size_download}\n' "$LB/large.bin" > "$WORK/l0.curl" &
cpid=$!
sleep 2
during="$(used)"
section "L0 Large response to a slow client, free space" "A $((LARGE_BYTES / 1048576)) MiB upstream response read by a client limited to $RATE per second, with 16 KiB of proxy buffers."
show "lsof -nP +L1 2> /dev/null | grep -E '^COMMAND|/var/lib/nginx/'"
temp_open="$(lsof -nP +L1 2> /dev/null | grep -c '/var/lib/nginx/proxy' || true)"
l0_rc=0
wait "$cpid" || l0_rc=$?
read -r l0_code l0_bytes < "$WORK/l0.curl" || true
l0_code="${l0_code:-000}"
l0_bytes="${l0_bytes:-0}"
show "grep -F 'buffered to a temporary file' $ERROR_LOG"
spill="$(count 'an upstream response is buffered to a temporary file')"
match=no
if [ "$temp_open" -ge 1 ] && [ "$l0_code" = 200 ] && [ "$l0_bytes" = "$LARGE_BYTES" ] && [ "$l0_rc" -eq 0 ]; then match=yes; fi
result L0 "Large response, slow client, free space" "The response spills to a deleted temp file under the proxy temp path" "$temp_open deleted temp file(s) open, used +$(kib $((during - before))) KiB during the transfer, $spill warn line(s), client got $l0_code with $l0_bytes of $LARGE_BYTES bytes" "$match"

base_body="$(code_of --data-binary @"$WORK/body.bin" "$LB/echo")"
body_spill="$(count 'a client request body is buffered to a temporary file')"

log "L9 filling the filesystem as www-data"
section "L9 Fill as www-data, then write as root" "The filler runs as the NGINX worker user, so it stops at the root reserve."
show "su -s /bin/sh www-data -c 'dd if=/dev/zero of=$FS/fill/www-data.fill bs=64k status=none'"
show "su -s /bin/sh www-data -c 'dd if=/dev/zero of=$FS/fill/www-data.tail bs=4k status=none'"
sync
show "df -h $FS"
avail_nonroot="$(avail)"
root_rc=0
dd if=/dev/zero of="$FS/fill/root.fill" bs=4k count=32 status=none 2> "$WORK/root-dd.err" || root_rc=$?
sync
root_bytes="$(stat -c %s "$FS/fill/root.fill" 2> /dev/null || echo 0)"
show "ls -l $FS/fill"
rm -f "$FS/fill/root.fill"
sync
match=no
if [ "$avail_nonroot" -le 65536 ] && [ "$root_rc" -eq 0 ] && [ "$root_bytes" -eq 131072 ]; then match=yes; fi
result L9 "Root reserve" "Non-root writers stop at the reserve while root still writes" "$(kib "$avail_nonroot") KiB left for non-root after the fill, root wrote $root_bytes bytes, dd exit $root_rc" "$match"

log "L1 small responses on the full filesystem"
size_before="$(stat -c %s "$ACCESS_LOG")"
lines_before="$(lines "$ACCESS_LOG")"
ok=0
for _ in $(seq 1 200); do
  if [ "$(code_of "$LB/small.txt")" = 200 ]; then ok=$((ok + 1)); fi
done
size_after="$(stat -c %s "$ACCESS_LOG")"
logged=$(($(lines "$ACCESS_LOG") - lines_before))
section "L1 Small responses on the full filesystem" "Two hundred requests for a response that fits in the proxy buffers, enough log lines to need more than the free tail of the log's last 4 KiB block."
show "grep -F 'access.log' $ERROR_LOG | tail -n 3"
log_alerts="$(count 'access.log')"
match=no
if [ "$ok" -eq 200 ] && [ "$logged" -lt 200 ] && [ "$log_alerts" -ge 1 ]; then match=yes; fi
result L1 "Small responses, full filesystem" "Every request returns 200, some requests never reach the access log, and NGINX logs an alert about it" "$ok of 200 returned 200, $logged of 200 reached the access log ($((size_after - size_before)) bytes), $log_alerts alert line(s)" "$match"

log "L2 large response on the full filesystem"
l2_rc=0
curl -s -m 60 -o "$WORK/l2.out" --limit-rate "$RATE" -w '%{http_code} %{size_download}\n' "$LB/large.bin" > "$WORK/l2.curl" 2> /dev/null || l2_rc=$?
read -r l2_code l2_bytes < "$WORK/l2.curl" || true
l2_code="${l2_code:-000}"
l2_bytes="${l2_bytes:-0}"
section "L2 Large response on the full filesystem" "The same throttled request as L0, now with no space left for the worker."
show "grep -F '/var/lib/nginx/proxy' $ERROR_LOG | grep -F 'No space left on device' | tail -n 3"
match=no
if [ "$l2_code" = 200 ] && [ "$l2_bytes" -lt "$LARGE_BYTES" ] && [ "$l2_rc" -eq 18 ]; then match=yes; fi
result L2 "Large response, full filesystem" "The status line says 200, then the connection closes before Content-Length is reached" "status $l2_code, $l2_bytes of $LARGE_BYTES bytes, curl exit $l2_rc" "$match"

log "L3 request body on the full filesystem"
l3_code="$(code_of --data-binary @"$WORK/body.bin" "$LB/echo")"
section "L3 Request body above client_body_buffer_size on the full filesystem" "A $((BODY_BYTES / 1024)) KiB POST body against an 8 KiB client body buffer."
show "grep -F '/var/lib/nginx/body' $ERROR_LOG | tail -n 3"
match=no
if [ "$base_body" = 200 ] && [ "$l3_code" = 500 ]; then match=yes; fi
result L3 "Request body above the buffer, full filesystem" "The request fails with 500" "$base_body with free space after $body_spill spill warning(s), $l3_code on the full filesystem" "$match"

log "L10 lowering the reserve on the mounted, full filesystem"
avail_before="$(avail)"
section "L10 tune2fs -m 1 on the mounted, full filesystem" "Lowering the reserve from 5 % to 1 % while NGINX runs, then restoring it."
show "tune2fs -m 1 $LOOP"
sync
avail_after="$(avail)"
www_rc=0
su -s /bin/sh www-data -c "dd if=/dev/zero of=$FS/fill/after-reserve.fill bs=4k count=64 status=none" 2> "$WORK/l10.err" || www_rc=$?
show "df -h $FS"
tune2fs -m 5 "$LOOP" > /dev/null 2>&1 || log "could not restore the 5 % reserve"
rm -f "$FS/fill/after-reserve.fill"
match=no
if [ "$avail_after" -gt "$avail_before" ] && [ "$www_rc" -eq 0 ]; then match=yes; fi
result L10 "tune2fs -m 1 while mounted and full" "Non-root writers get space back at once, without a remount" "$(kib "$avail_before") KiB available before, $(kib "$avail_after") KiB after, a 256 KiB write as www-data exited $www_rc" "$match"

rm -f "$FS/fill/www-data.fill" "$FS/fill/www-data.tail"
sync

log "L4 and L5 deleted log held open"
head -c 2097152 /dev/zero >> "$ACCESS_LOG"
sync
u0="$(used)"
rm "$ACCESS_LOG"
sync
u1="$(used)"
section "L4 rm on the open access log" "The access log was padded by 2 MiB and then deleted while NGINX holds it open."
show "lsof -nP +L1 2> /dev/null | grep -E '^COMMAND|access.log'"
show "echo \"df used \$(df -B1 --output=used $FS | tail -n 1) bytes, du total \$(du -sxB1 $FS | cut -f1) bytes\""
nginx -s reopen
sleep 1
sync
u2="$(used)"
section "L5 nginx -s reopen after the rm" "NGINX reopens its logs, so the last descriptor of the deleted file closes."
show "lsof -nP +L1 2> /dev/null | grep -c access.log || true"
show "ls -l /var/log/nginx"
m4=no
m5=no
if [ $((u0 - u1)) -lt 65536 ]; then m4=yes; fi
if [ $((u0 - u2)) -ge 1572864 ]; then m5=yes; fi
result L4 "rm on an open log" "Nothing is freed while NGINX holds the file" "used $(kib "$u0") KiB before the rm, $(kib "$u1") KiB after" "$m4"
result L5 "nginx -s reopen after the rm" "The space of the deleted log comes back" "used $(kib "$u2") KiB after the reopen, $(kib $((u0 - u2))) KiB freed" "$m5"

log "L7 rename without reopen"
code_of "$LB/small.txt" > /dev/null
mv "$ACCESS_LOG" "$ACCESS_LOG.moved"
n0="$(lines "$ACCESS_LOG.moved")"
for _ in 1 2 3 4 5; do code_of "$LB/small.txt" > /dev/null; done
n1="$(lines "$ACCESS_LOG.moved")"
present=no
if [ -e "$ACCESS_LOG" ]; then present=yes; fi
nginx -s reopen
sleep 1
for _ in 1 2 3; do code_of "$LB/small.txt" > /dev/null; done
n_new="$(lines "$ACCESS_LOG")"
n2="$(lines "$ACCESS_LOG.moved")"
section "L7 Rename without reopen" "The access log is renamed with mv, five requests follow, then a reopen and three more requests."
show "ls -l /var/log/nginx"
rm -f "$ACCESS_LOG.moved"
match=no
if [ $((n1 - n0)) -eq 5 ] && [ "$present" = no ] && [ "$n_new" -eq 3 ] && [ "$n2" -eq "$n1" ]; then match=yes; fi
result L7 "Rename without reopen" "NGINX keeps writing to the renamed file until a reopen" "renamed file got $((n1 - n0)) of 5 lines, a new access.log existed before the reopen: $present, after the reopen it got $n_new of 3 lines" "$match"

log "L6 logrotate with the fixture configuration"
install -d -m 0755 /etc/logrotate.lab
install -m 0644 -o root -g root "$LAB_DIR/logrotate-nginx.conf" /etc/logrotate.lab/nginx
code_of "$LB/small.txt" > /dev/null
section "L6 logrotate -f with the fixture configuration" "The fixture keeps the package rules and calls nginx -s reopen in postrotate, because invoke-rc.d does nothing in a container."
show "logrotate -d -s $WORK/logrotate.state /etc/logrotate.lab/nginx 2>&1 | tail -n 15"
show "logrotate -f -v -s $WORK/logrotate.state /etc/logrotate.lab/nginx"
sleep 1
r1="$(lines "$ACCESS_LOG.1")"
for _ in 1 2 3; do code_of "$LB/small.txt" > /dev/null; done
n_cur="$(lines "$ACCESS_LOG")"
r2="$(lines "$ACCESS_LOG.1")"
show "ls -l /var/log/nginx"
match=no
if [ -e "$ACCESS_LOG.1" ] && [ "$n_cur" -eq 3 ] && [ "$r2" -eq "$r1" ]; then match=yes; fi
result L6 "logrotate -f on fixture logs" "The log is renamed and new lines go to the new file" "access.log.1 holds $r2 line(s) and did not grow, the new access.log got $n_cur of 3 lines" "$match"

log "L8 inode exhaustion"
truncate -s 8M "$WORK/inodes.img"
mkfs.ext4 -q -F -N 64 -m 5 "$WORK/inodes.img"
INODE_LOOP="$(losetup --find --show "$WORK/inodes.img")" || { echo "no free loop device in this Docker VM" >&2; exit 1; }
mount "$INODE_LOOP" "$INODE_FS"
mkdir "$INODE_FS/small"
n=0
while [ "$n" -lt 100000 ] && : 2> /dev/null > "$INODE_FS/small/f$n"; do n=$((n + 1)); done
section "L8 Inode exhaustion" "An 8 MiB ext4 filesystem created with 64 inodes, filled with empty files."
show "df -i $INODE_FS"
show "df -h $INODE_FS"
show "touch $INODE_FS/one-more"
iuse="$(df --output=ipcent "$INODE_FS" | tail -n 1 | tr -d ' %')"
bavail="$(df -B1 --output=avail "$INODE_FS" | tail -n 1 | tr -d ' ')"
match=no
if [ "$iuse" = 100 ] && [ "$bavail" -gt 0 ]; then match=yes; fi
result L8 "Inode exhaustion" "No space left on device while blocks are still free" "$n empty files created, inodes $iuse % used, $(kib "$bavail") KiB of blocks still available" "$match"

log "done"
