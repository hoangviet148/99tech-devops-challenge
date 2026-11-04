#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
P3_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$P3_DIR/tests"
PROBE_DIR="$P3_DIR/evidence/probes"
PROJECT="p3verify"
HOST_URL="http://127.0.0.1:18080"
TOXI_URL="http://127.0.0.1:18474"
K6_IMAGE="grafana/k6:1.3.0@sha256:3ddc8b1a33a2c3d8edc6e99b6a762ae36cba08788463458f5e6a7703e14eb77d"
PLACEHOLDER_IMAGE="alpine:3.22@sha256:2e0b81d60597f449baa56dc25d355367869d2dca4cd57e866f1e2b52af3eb55f"
POOL_MAX=4
APP_CONN_MAX=20
SCENARIOS="S1 S2 S3 S4 S5 S6 S7 S8 S9 S11 S12"

PROFILE="after"
STACK_DIR="$P3_DIR"
ONLY=""
OUT=""
YES=0
EXTRA=()
NET=""

usage() {
  cat <<'EOF'
Usage: bash scripts/verify.sh --yes [--profile after|before] [--stack-dir DIR] [--only S1,S3] [--out FILE]

Runs the failure-injection scenarios S1 to S12 against a compose stack under the project name p3verify.
Every scenario tears the project down and recreates it, which is why --yes is required.
--profile before runs an upstream checkout with the probe overrides from evidence/probes.
S10 is measured during S3. Requires docker with compose, curl, jq and perl.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --stack-dir) STACK_DIR="${2:-}"; shift 2 ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$YES" -ne 1 ]; then
  echo "verify.sh recreates the compose project $PROJECT for every scenario, pass --yes to continue" >&2
  exit 2
fi
case "$PROFILE" in after|before) ;; *) echo "--profile must be after or before" >&2; exit 2 ;; esac
for tool in docker curl jq perl awk sort; do
  command -v "$tool" >/dev/null 2>&1 || { echo "missing tool: $tool" >&2; exit 2; }
done
[ -f "$STACK_DIR/docker-compose.yml" ] || { echo "no docker-compose.yml in $STACK_DIR" >&2; exit 2; }
STACK_DIR="$(cd "$STACK_DIR" && pwd)"

RUN_ID="$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/p3verify.XXXXXX")"
[ -n "$OUT" ] || OUT="$P3_DIR/evidence/verify-$PROFILE-$RUN_ID.md"
RESULTS="$WORK/results.tsv"
: > "$RESULTS"
export P3_PROBE_DIR="$PROBE_DIR"
export P3_TESTS_DIR="$TESTS_DIR"

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
now_ms() { perl -MTime::HiRes=time -e 'printf("%d\n", time() * 1000)'; }
sleep_until_ms() {
  local target="$1"
  while [ "$(now_ms)" -lt "$target" ]; do sleep 0.2; done
}
lt() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 < b + 0) }'; }
le() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a + 0 <= b + 0) }'; }

compose() {
  local args=(-p "$PROJECT" --project-directory "$STACK_DIR" -f "$STACK_DIR/docker-compose.yml" -f "$TESTS_DIR/compose.verify.yml")
  local f
  for f in ${EXTRA[@]+"${EXTRA[@]}"}; do args+=(-f "$f"); done
  docker compose "${args[@]}" "$@"
}

files_for() {
  EXTRA=()
  if [ "$PROFILE" = "before" ]; then
    case "$1" in
      S1) ;;
      S5) EXTRA=("$PROBE_DIR/before-port-fix.yml" "$TESTS_DIR/compose.toxiproxy.before.yml") ;;
      S7) EXTRA=("$PROBE_DIR/before-port-fix.yml" "$PROBE_DIR/before-init-sql.yml") ;;
      *) EXTRA=("$PROBE_DIR/before-port-fix.yml") ;;
    esac
  else
    case "$1" in
      S5) EXTRA=("$TESTS_DIR/compose.toxiproxy.after.yml") ;;
    esac
  fi
}

remove_labelled() {
  local id
  docker ps -aq --filter "label=$1" | while read -r id; do docker rm -f "$id" >/dev/null 2>&1; done
}

down() {
  remove_labelled p3verify.k6=1
  remove_labelled p3verify.placeholder=1
  compose down -v --remove-orphans >/dev/null 2>&1 || true
}

# shellcheck disable=SC2329
cleanup() {
  EXTRA=("$TESTS_DIR/compose.toxiproxy.after.yml")
  [ "$PROFILE" = "before" ] && EXTRA=("$TESTS_DIR/compose.toxiproxy.before.yml")
  down
}
trap cleanup EXIT

http_code() {
  local c
  c="$(curl -s -o /dev/null -m "${2:-5}" -w '%{http_code}' "$HOST_URL$1" 2>/dev/null)"
  printf '%s' "${c:-000}"
}

wait_http() {
  local path="$1" want="$2" seconds="$3" start now
  start="$(now_ms)"
  while true; do
    if [ "$(http_code "$path" 2)" = "$want" ]; then
      now="$(now_ms)"
      echo $((now - start))
      return 0
    fi
    now="$(now_ms)"
    [ $((now - start)) -lt $((seconds * 1000)) ] || return 1
    sleep 0.5
  done
}

nginx_network() {
  local id
  id="$(compose ps -q nginx | head -n 1)"
  [ -n "$id" ] || return 1
  docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}' "$id" | head -n 1
}

stack_up() {
  down
  if [ "$PROFILE" = "after" ]; then
    if ! compose up -d --build --wait --wait-timeout 180 "$@" > "$WORK/up.log" 2>&1; then
      log "stack did not become healthy"
      tail -n 20 "$WORK/up.log" >&2
      return 1
    fi
  else
    if ! compose up -d --build "$@" > "$WORK/up.log" 2>&1; then
      log "stack failed to start"
      tail -n 20 "$WORK/up.log" >&2
      return 1
    fi
    wait_http / 200 60 > /dev/null || true
    sleep 5
  fi
  NET="$(nginx_network)"
}

api_ids() { compose ps -q api; }
first_api() { api_ids | head -n 1; }

api_ips() {
  local id
  for id in $(api_ids); do
    docker inspect -f "{{with index .NetworkSettings.Networks \"$NET\"}}{{.IPAddress}}{{end}}" "$id"
  done | sort
}

restart_total() {
  local id total=0 n
  for id in $(compose ps -aq api); do
    n="$(docker inspect -f '{{.RestartCount}}' "$id" 2>/dev/null || echo 0)"
    total=$((total + n))
  done
  echo "$total"
}

api_running() {
  local id n=0
  for id in $(compose ps -aq api); do
    [ "$(docker inspect -f '{{.State.Running}}' "$id" 2>/dev/null)" = "true" ] && n=$((n + 1))
  done
  echo "$n"
}

health_of() { docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1" 2>/dev/null; }

wait_healthy() {
  local id="$1" seconds="$2" i h
  for i in $(seq 1 $((seconds * 2))); do
    h="$(health_of "$id")"
    if [ "$h" = "healthy" ]; then return 0; fi
    if [ "$h" = "none" ] && [ "$(docker inspect -f '{{.State.Running}}' "$id" 2>/dev/null)" = "true" ]; then return 0; fi
    sleep 0.5
  done
  return 1
}

wait_pg_ready() {
  local seconds="$1" i
  for i in $(seq 1 $((seconds * 4))); do
    if compose exec -T postgres pg_isready -U postgres -q > /dev/null 2>&1; then now_ms; return 0; fi
    sleep 0.25
  done
  return 1
}

pg_app_connections() {
  compose exec -T postgres psql -U postgres -d postgres -tAc \
    "select count(*) from pg_stat_activity where backend_type = 'client backend' and application_name not like 'psql%'" 2>/dev/null | tr -d ' \r'
}

k6_start() {
  local name="$1" rate="$2" duration="$3" vus="${4:-0}" dir="$WORK/k6-$1" executor="rate"
  [ "$vus" -gt 0 ] && executor="vus"
  mkdir -p "$dir"
  chmod 777 "$dir"
  docker run -d --name "$PROJECT-k6-$name" --label p3verify.k6=1 --network "$NET" \
    -e TARGET=http://nginx -e RATE="$rate" -e DURATION="$duration" -e EXECUTOR="$executor" -e VUS="$vus" \
    -v "$dir:/out" -v "$TESTS_DIR:/tests:ro" "$K6_IMAGE" run --quiet \
    --summary-trend-stats "avg,min,med,max,p(95),p(99)" --summary-export /out/summary.json \
    --out json=/out/requests.json /tests/load.js > /dev/null
}

k6_wait() {
  local name="$1" dir="$WORK/k6-$1"
  docker wait "$PROJECT-k6-$name" > /dev/null 2>&1
  docker logs "$PROJECT-k6-$name" > "$dir/k6.log" 2>&1
  docker rm "$PROJECT-k6-$name" > /dev/null 2>&1
  jq -r 'select(.type == "Point" and .metric == "http_req_duration")
    | .data as $d
    | ($d.time | capture("^(?<b>[0-9T:-]+)(\\.(?<f>[0-9]+))?Z$")) as $t
    | [(($t.b + "Z" | fromdateiso8601) * 1000 + ((($t.f // "0") + "000")[0:3] | tonumber)), $d.value, $d.tags.status]
    | @tsv' "$dir/requests.json" > "$dir/points.tsv" 2>/dev/null
  rm -f "$dir/requests.json"
}

k6_metric() { jq -r "$2" "$WORK/k6-$1/summary.json" 2>/dev/null; }
points() { echo "$WORK/k6-$1/points.tsv"; }

win_count() { awk -F'\t' -v s="$2" -v e="$3" '$1 >= s && $1 <= e { n++ } END { print n + 0 }' "$1"; }
win_bad() { awk -F'\t' -v s="$2" -v e="$3" '$1 >= s && $1 <= e && $3 != "200" { n++ } END { print n + 0 }' "$1"; }
out_bad() { awk -F'\t' -v s="$2" -v e="$3" '($1 < s || $1 > e) && $3 != "200" { n++ } END { print n + 0 }' "$1"; }
win_max() { awk -F'\t' -v s="$2" -v e="$3" '$1 >= s && $1 <= e && $2 > m { m = $2 } END { printf "%.0f\n", m + 0 }' "$1"; }
win_status() { awk -F'\t' -v s="$2" -v e="$3" '$1 >= s && $1 <= e { c[$3]++ } END { for (k in c) printf "%s=%d ", k, c[k] }' "$1"; }
win_p99() {
  awk -F'\t' -v s="$2" -v e="$3" '$1 >= s && $1 <= e { print $2 }' "$1" | sort -n |
    awk '{ a[NR] = $1 } END { if (NR == 0) { print "n/a"; exit } i = int(NR * 0.99 + 0.5); if (i < 1) i = 1; if (i > NR) i = NR; printf "%.1f\n", a[i] }'
}
last_ms() { awk -F'\t' '$1 > m { m = $1 } END { print m + 0 }' "$1"; }
median() { sort -n | awk '{ a[NR] = $1 } END { if (NR == 0) { print 0; exit } print a[int((NR + 1) / 2)] }'; }

record() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" >> "$RESULTS"
  log "$1 $3: $4"
}

toxic() {
  local action="$1" stream
  for stream in downstream upstream; do
    if [ "$action" = "add" ]; then
      curl -s -o /dev/null -X POST "$TOXI_URL/proxies/redis/toxics" -H 'Content-Type: application/json' \
        -d "{\"name\":\"hole_$stream\",\"type\":\"timeout\",\"stream\":\"$stream\",\"toxicity\":1,\"attributes\":{\"timeout\":0}}"
    else
      curl -s -o /dev/null -X DELETE "$TOXI_URL/proxies/redis/toxics/hole_$stream"
    fi
  done
}

s1() {
  local name="GET /api/users through nginx" c
  files_for S1
  stack_up || { record S1 "$name" FAIL "stack did not start"; return; }
  c="$(http_code /api/users 10)"
  if [ "$c" = "200" ]; then record S1 "$name" PASS "HTTP $c"; else record S1 "$name" FAIL "HTTP $c"; fi
}

s2() {
  local name="200 requests/s for 60 s, dependencies healthy" failed dropped p99 total v=FAIL
  files_for S2
  stack_up --scale api=2 || { record S2 "$name" FAIL "stack did not start"; return; }
  k6_start s2 200 60s
  k6_wait s2
  failed="$(k6_metric s2 '.metrics.http_req_failed.passes // 0')"
  dropped="$(k6_metric s2 '.metrics.dropped_iterations.count // 0')"
  total="$(k6_metric s2 '.metrics.http_reqs.count // 0')"
  p99="$(k6_metric s2 '.metrics.http_req_duration["p(99)"] // 0')"
  if [ "$failed" = "0" ] && [ "$dropped" = "0" ] && lt "$p99" 100; then v=PASS; fi
  record S2 "$name" "$v" "$total requests, $failed failed, $dropped dropped, p99 $(printf '%.1f' "$p99") ms"
}

sample_api() {
  local out="$1" n="$2" i id metrics pool m_rss m_fds rss fds total idle waiting tmax
  : > "$out"
  for i in $(seq 1 "$n"); do
    rss=0; fds=0; idle=0; waiting=0; tmax=0
    for id in $(api_ids); do
      metrics="$(docker exec "$id" sh -c 'p=$(pidof node) || exit 1; awk "/VmRSS/ { print \$2 }" /proc/$p/status; ls /proc/$p/fd | wc -l' 2>/dev/null | tr '\n' ' ')"
      read -r m_rss m_fds <<< "$metrics"
      rss=$((rss + ${m_rss:-0})); fds=$((fds + ${m_fds:-0}))
      pool="$(docker exec "$id" wget -qO- -T 2 http://127.0.0.1:3000/internal/pool 2>/dev/null)"
      if [ -n "$pool" ]; then
        total="$(echo "$pool" | jq -r '.total // 0')"
        idle=$((idle + $(echo "$pool" | jq -r '.idle // 0')))
        waiting=$((waiting + $(echo "$pool" | jq -r '.waiting // 0')))
        if [ "${total:-0}" -gt "$tmax" ]; then tmax="$total"; fi
      else
        tmax=-1
      fi
    done
    printf '%s\t%s\t%s\t%s\t%s\n' "$rss" "$fds" "$tmax" "$idle" "$waiting" >> "$out"
    sleep 2
  done
}

s3() {
  local name3="Postgres restart under load, 5 times" name10="Pool health across the 5 faults of S3"
  local cycle t0 t_stop t_ready pts bad detail="" ok3=1 ok10=1 detail10="" base_restarts
  local samples rss fds tmax idle waiting fresh base_rss="" base_fds="" base_idle=""
  files_for S3
  stack_up --scale api=2 || { record S3 "$name3" FAIL "stack did not start"; record S10 "$name10" FAIL "stack did not start"; return; }
  base_restarts="$(restart_total)"
  for cycle in 1 2 3 4 5; do
    log "S3 cycle $cycle of 5"
    t0="$(now_ms)"
    k6_start "s3c$cycle" 200 90s
    sleep_until_ms $((t0 + 10000))
    t_stop="$(now_ms)"
    compose restart postgres > /dev/null 2>&1
    t_ready="$(wait_pg_ready 60)" || t_ready="$(now_ms)"
    sleep_until_ms $((t0 + 40000))
    samples="$WORK/s10-c$cycle.tsv"
    sample_api "$samples" 14
    k6_wait "s3c$cycle"
    pts="$(points "s3c$cycle")"
    bad="$(out_bad "$pts" "$t_stop" $((t_ready + 5000)))"
    [ "$bad" -eq 0 ] || ok3=0
    detail="$detail c$cycle: outage $((t_ready - t_stop)) ms, $bad errors outside the window."
    fresh="$(http_code /api/users 5)"
    rss="$(cut -f1 "$samples" | median)"
    fds="$(cut -f2 "$samples" | median)"
    tmax="$(cut -f3 "$samples" | sort -n | tail -n 1)"
    idle="$(cut -f4 "$samples" | median)"
    waiting="$(cut -f5 "$samples" | sort -n | tail -n 1)"
    if [ "$cycle" -eq 1 ]; then base_rss="$rss"; base_fds="$fds"; base_idle="$idle"; fi
    if [ "$fresh" != "200" ] || [ "$tmax" -lt 0 ] || [ "$tmax" -gt "$POOL_MAX" ] || [ "${waiting:-1}" -ne 0 ]; then ok10=0; fi
    if [ "$idle" -lt $((base_idle - 2)) ] || [ "$idle" -gt $((base_idle + 2)) ]; then ok10=0; fi
    if [ "$base_rss" -gt 0 ] && ! le "$rss" "$(awk -v b="$base_rss" 'BEGIN { print b * 1.10 }')"; then ok10=0; fi
    if [ "$base_fds" -gt 0 ] && ! le "$fds" "$(awk -v b="$base_fds" 'BEGIN { print b * 1.10 }')"; then ok10=0; fi
    detail10="$detail10 c$cycle: fresh $fresh, pool total max $tmax, waiting $waiting, idle $idle, RSS ${rss} kB, fds $fds."
  done
  local restarts running
  restarts="$(restart_total)"
  running="$(api_running)"
  if [ "$running" -ne 2 ] || [ "$restarts" -ne "$base_restarts" ]; then ok3=0; fi
  detail="replicas running $running of 2, restarts $((restarts - base_restarts)).$detail"
  if [ "$ok3" -eq 1 ]; then record S3 "$name3" PASS "$detail"; else record S3 "$name3" FAIL "$detail"; fi
  if [ "$ok10" -eq 1 ]; then record S10 "$name10" PASS "$detail10"; else record S10 "$name10" FAIL "$detail10"; fi
}

s4() {
  local name="Postgres paused for 15 s under load" t0 t_p t_u pts maxd after_bad statuses end v=FAIL
  files_for S4
  stack_up --scale api=2 || { record S4 "$name" FAIL "stack did not start"; return; }
  t0="$(now_ms)"
  k6_start s4 200 45s
  sleep_until_ms $((t0 + 10000))
  t_p="$(now_ms)"
  compose pause postgres > /dev/null 2>&1
  sleep_until_ms $((t_p + 15000))
  t_u="$(now_ms)"
  compose unpause postgres > /dev/null 2>&1
  k6_wait s4
  pts="$(points s4)"
  end="$(last_ms "$pts")"
  maxd="$(win_max "$pts" "$t_p" $((t_u + 2500)))"
  statuses="$(win_status "$pts" $((t_p + 2500)) "$t_u")"
  after_bad="$(win_bad "$pts" $((t_u + 5000)) "$end")"
  if le "$maxd" 2500 && [ "$after_bad" -eq 0 ]; then v=PASS; fi
  record S4 "$name" "$v" "slowest response while paused $maxd ms, statuses while paused ${statuses:-none}, errors from 5 s after unpause $after_bad"
}

s5_case() {
  local label="$1" pts p99 bad end t0 t_f
  t0="$(now_ms)"
  k6_start "s5$label" 200 30s
  sleep_until_ms $((t0 + 10000))
  t_f="$(now_ms)"
  case "$label" in
    stop) compose stop redis > /dev/null 2>&1 ;;
    pause) compose pause redis > /dev/null 2>&1 ;;
    hole) toxic add ;;
  esac
  k6_wait "s5$label"
  case "$label" in
    stop) compose start redis > /dev/null 2>&1 ;;
    pause) compose unpause redis > /dev/null 2>&1 ;;
    hole) toxic remove ;;
  esac
  sleep 3
  pts="$(points "s5$label")"
  end="$(last_ms "$pts")"
  p99="$(win_p99 "$pts" $((t_f + 1000)) "$end")"
  bad="$(win_bad "$pts" $((t_f + 1000)) "$end")"
  printf '%s\t%s\t%s\n' "$label" "$p99" "$bad"
}

s5() {
  local name="Redis stopped, paused and blackholed" line label p99 bad ok=1 detail=""
  files_for S5
  stack_up --scale api=2 || { record S5 "$name" FAIL "stack did not start"; return; }
  for label in stop pause hole; do
    line="$(s5_case "$label")"
    p99="$(echo "$line" | cut -f2)"
    bad="$(echo "$line" | cut -f3)"
    if [ "$p99" = "n/a" ] || ! lt "$p99" 100 || [ "$bad" -ne 0 ]; then ok=0; fi
    detail="$detail $label: p99 $p99 ms, $bad non-200."
  done
  if [ "$ok" -eq 1 ]; then record S5 "$name" PASS "$detail"; else record S5 "$name" FAIL "$detail"; fi
}

s6() {
  local name="Every API replica recreated while placeholders hold the old IPs" old new ip overlap=0 elapsed
  files_for S6
  stack_up --scale api=2 || { record S6 "$name" FAIL "stack did not start"; return; }
  old="$(api_ips | tr '\n' ' ')"
  compose rm -sf api > /dev/null 2>&1
  docker run -d --label p3verify.placeholder=1 --network "$NET" "$PLACEHOLDER_IMAGE" sleep 600 > /dev/null
  docker run -d --label p3verify.placeholder=1 --network "$NET" "$PLACEHOLDER_IMAGE" sleep 600 > /dev/null
  if [ "$PROFILE" = "after" ]; then
    compose up -d --no-deps --wait --wait-timeout 120 --scale api=2 api > /dev/null 2>&1
  else
    compose up -d --no-deps --scale api=2 api > /dev/null 2>&1
    sleep 3
  fi
  new="$(api_ips | tr '\n' ' ')"
  for ip in $new; do
    case " $old " in *" $ip "*) overlap=1 ;; esac
  done
  if elapsed="$(wait_http /api/users 200 15)"; then
    if [ "$overlap" -eq 0 ]; then
      record S6 "$name" PASS "old IPs $old, new IPs $new, first 200 after $elapsed ms"
    else
      record S6 "$name" INCONCLUSIVE "a new replica reused an old IP ($old to $new)"
    fi
  else
    record S6 "$name" FAIL "old IPs $old, new IPs $new, no 200 within 15 s, last HTTP $(http_code /api/users 2)"
  fi
  remove_labelled p3verify.placeholder=1
}

s7() {
  local name="4 replicas, 120 concurrent clients for 60 s" i c max=0 admin="no" failed total tmc v=FAIL
  files_for S7
  stack_up --scale api=4 || { record S7 "$name" FAIL "stack did not start"; return; }
  k6_start s7 0 60s 120
  for i in $(seq 1 28); do
    sleep 2
    c="$(pg_app_connections)"
    if [ -n "$c" ] && [ "$c" -gt "$max" ]; then max="$c"; fi
    if [ "$i" -eq 15 ]; then
      if [ "$(compose exec -T postgres psql -U postgres -d postgres -tAc 'select 1' 2>/dev/null | tr -d ' \r')" = "1" ]; then admin="yes"; fi
    fi
  done
  k6_wait s7
  failed="$(k6_metric s7 '.metrics.http_req_failed.passes // 0')"
  total="$(k6_metric s7 '.metrics.http_reqs.count // 0')"
  tmc="$(compose logs api 2>&1 | grep -c 'too many clients')"
  if [ "$failed" = "0" ] && [ "$tmc" = "0" ] && [ "$max" -le "$APP_CONN_MAX" ] && [ "$admin" = "yes" ]; then v=PASS; fi
  record S7 "$name" "$v" "$total requests, $failed failed, $tmc too-many-clients log lines, app connections max $max, admin psql $admin"
}

s8() {
  local name="kill -9 on one of two replicas under load" victim base t0 t_k t_rejoin="" i rc pts n bad rate after_bad end v=FAIL
  files_for S8
  stack_up --scale api=2 || { record S8 "$name" FAIL "stack did not start"; return; }
  victim="$(first_api)"
  base="$(docker inspect -f '{{.RestartCount}}' "$victim")"
  t0="$(now_ms)"
  k6_start s8 200 50s
  sleep_until_ms $((t0 + 10000))
  t_k="$(now_ms)"
  if [ "$PROFILE" = "after" ]; then
    docker exec "$victim" sh -c 'kill -9 "$(pidof node)"' > /dev/null 2>&1
  else
    docker kill -s KILL "$victim" > /dev/null 2>&1
  fi
  for i in $(seq 1 60); do
    sleep 0.5
    rc="$(docker inspect -f '{{.RestartCount}}' "$victim" 2>/dev/null || echo "$base")"
    if [ "$rc" -gt "$base" ] && [ "$(health_of "$victim")" = "healthy" ]; then t_rejoin="$(now_ms)"; break; fi
  done
  k6_wait s8
  pts="$(points s8)"
  end="$(last_ms "$pts")"
  n="$(win_count "$pts" "$t_k" $((t_k + 10000)))"
  bad="$(win_bad "$pts" "$t_k" $((t_k + 10000)))"
  rate="$(awk -v b="$bad" -v n="$n" 'BEGIN { if (n == 0) print 100; else printf "%.2f", b * 100 / n }')"
  rc="$(docker inspect -f '{{.RestartCount}}' "$victim" 2>/dev/null || echo "$base")"
  if [ -n "$t_rejoin" ]; then after_bad="$(win_bad "$pts" "$t_rejoin" "$end")"; else after_bad="n/a"; fi
  if lt "$rate" 0.5 && [ -n "$t_rejoin" ] && [ "$after_bad" = "0" ] && [ "$rc" -eq $((base + 1)) ]; then v=PASS; fi
  record S8 "$name" "$v" "error rate in the 10 s after the kill $rate % ($bad of $n), restarts $((rc - base)), rejoined ${t_rejoin:+yes}${t_rejoin:-no}, errors after rejoin $after_bad"
}

stop_timed() {
  local id="$1" ts te
  ts="$(now_ms)"
  docker stop -t 10 "$id" > /dev/null 2>&1
  te="$(now_ms)"
  printf '%s\t%s\t%s\n' "$((te - ts))" "$(docker inspect -f '{{.State.ExitCode}}' "$id")" "$ts"
}

s9() {
  local name="docker stop on one replica, healthy and with Postgres paused" victim t0 line ea ca ts pts bad eb cb v=FAIL
  files_for S9
  stack_up --scale api=2 || { record S9 "$name" FAIL "stack did not start"; return; }
  victim="$(first_api)"
  t0="$(now_ms)"
  k6_start s9 100 30s
  sleep_until_ms $((t0 + 10000))
  line="$(stop_timed "$victim")"
  ea="$(echo "$line" | cut -f1)"
  ca="$(echo "$line" | cut -f2)"
  ts="$(echo "$line" | cut -f3)"
  k6_wait s9
  pts="$(points s9)"
  bad="$(win_bad "$pts" "$ts" $((ts + ea + 1000)))"
  docker start "$victim" > /dev/null 2>&1
  wait_healthy "$victim" 60 || true
  compose pause postgres > /dev/null 2>&1
  line="$(stop_timed "$victim")"
  compose unpause postgres > /dev/null 2>&1
  eb="$(echo "$line" | cut -f1)"
  cb="$(echo "$line" | cut -f2)"
  if [ "$ea" -le 3000 ] && [ "$ca" = "0" ] && [ "$bad" -eq 0 ] && [ "$eb" -le 9000 ]; then v=PASS; fi
  record S9 "$name" "$v" "healthy: stop took $ea ms, exit $ca, $bad non-200 during the stop. Postgres paused: stop took $eb ms, exit $cb"
}

s11() {
  local name="Cold start, fresh volume and existing volume" c1 c2 v=FAIL
  files_for S11
  down
  if [ "$PROFILE" = "after" ]; then compose up -d --build --wait --wait-timeout 180 > /dev/null 2>&1; else compose up -d --build > /dev/null 2>&1; fi
  c1="$(http_code /api/users 10)"
  compose down > /dev/null 2>&1
  if [ "$PROFILE" = "after" ]; then compose up -d --wait --wait-timeout 180 > /dev/null 2>&1; else compose up -d > /dev/null 2>&1; fi
  c2="$(http_code /api/users 10)"
  if [ "$c1" = "200" ] && [ "$c2" = "200" ]; then v=PASS; fi
  record S11 "$name" "$v" "first request after start: fresh volume HTTP $c1, existing volume HTTP $c2"
}

s12() {
  local name="Cold start with Redis scaled to 0" start c ms n v=FAIL
  files_for S12
  down
  if [ "$PROFILE" = "after" ]; then
    compose up -d --build --wait --wait-timeout 180 --scale redis=0 > /dev/null 2>&1
  else
    compose up -d --build --scale redis=0 > /dev/null 2>&1
    sleep 5
  fi
  start="$(now_ms)"
  c="$(http_code /api/users 25)"
  ms=$(( $(now_ms) - start ))
  n="$(compose ps -q redis | wc -l | tr -d ' ')"
  if [ "$c" = "200" ] && [ "$n" = "0" ]; then v=PASS; fi
  record S12 "$name" "$v" "HTTP $c after $ms ms, Redis containers $n"
}

should_run() {
  [ -z "$ONLY" ] && return 0
  case ",$ONLY," in *",$1,"*) return 0 ;; esac
  [ "$1" = "S3" ] && case ",$ONLY," in *",S10,"*) return 0 ;; esac
  return 1
}

log "profile $PROFILE, stack $STACK_DIR, work dir $WORK"
for s in $SCENARIOS; do
  if should_run "$s"; then
    log "running $s"
    case "$s" in
      S1) s1 ;; S2) s2 ;; S3) s3 ;; S4) s4 ;; S5) s5 ;; S6) s6 ;;
      S7) s7 ;; S8) s8 ;; S9) s9 ;; S11) s11 ;; S12) s12 ;;
    esac
  fi
done

{
  echo "# verify.sh results, profile $PROFILE"
  echo
  echo "| Field | Value |"
  echo "|---|---|"
  echo "| Run | $RUN_ID |"
  tree_state="clean working tree"
  [ -z "$(git -C "$STACK_DIR" status --porcelain -- . 2>/dev/null)" ] || tree_state="uncommitted changes present"
  echo "| Stack | \`$(basename "$(dirname "$STACK_DIR")")/$(basename "$STACK_DIR")\` at commit \`$(git -C "$STACK_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)\`, $tree_state |"
  echo "| Docker | $(docker version --format '{{.Server.Version}} on {{.Server.Os}}/{{.Server.Arch}}'), Compose $(docker compose version --short) |"
  echo
  echo "| ID | Scenario | Result | Measured |"
  echo "|---|---|---|---|"
  sort -t "$(printf '\t')" -k1.2,1n "$RESULTS" | awk -F'\t' '{ printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4 }'
} > "$OUT"
log "results written to $OUT"

fails="$(awk -F'\t' '$3 != "PASS" { n++ } END { print n + 0 }' "$RESULTS")"
if [ "$PROFILE" = "after" ] && [ "$fails" -gt 0 ]; then exit 1; fi
exit 0
