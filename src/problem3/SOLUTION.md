# Problem 3: an unreliable API on Docker Compose

The stack is nginx in front of a Node.js API that reads Postgres and writes Redis. Users reported that the API is unreliable and sometimes unreachable. The API is fast while every dependency is healthy. It fails hard and stays down when a dependency blips, and one port typo makes every `/api` request fail today.

```bash
docker compose up --build
curl -s http://localhost:8080/api/users
```

A volume created by an earlier version of this stack needs `docker compose down -v` once, because the init script that creates the database role runs only on an empty data directory.

## 1. Requirements and principles

| Requirement | Where it is met |
|---|---|
| REQ-P3-1 Identify the issues | Section 3, findings F0 to F12 |
| REQ-P3-2 Fix them | Section 4, one commit per root cause |
| REQ-P3-3 Explain the root causes | Sections 2 and 3 |
| REQ-P3-4 Report diagnosis, fixes, monitoring and prevention | Sections 2 to 7 |
| REQ-P3-5 `docker compose up --build` serves on port 8080 | Healthchecks, readiness and local defaults (ADR-P3-0006, ADR-P3-0010) |

These AWS Well-Architected design principles drive the fixes. Each ADR in `docs/adr/` names the principles it applies and the ones it trades against.

| ID | Principle | Where it shows |
|---|---|---|
| REL-DP1 | "Automatically recover from failure" | Crash-only exit with a restart policy, nginx skipping a failed replica |
| REL-DP2 | "Test recovery procedures" | `scripts/verify.sh` injects every fault before and after the fixes |
| REL-DP3 | "Scale horizontally to increase aggregate workload availability" | Two API replicas behind nginx |
| REL-DP4 | "Stop guessing capacity" | An explicit Postgres connection budget |
| OPS-DP2 | "Implement observability for actionable insights" | Metrics, a probe through nginx, alert rules with tests |
| OPS-DP4 | "Make frequent, small, reversible changes" | One commit per root cause, each verified |
| OPS-DP6 | "Anticipate failure" | One deadline per request, Redis off the request path |
| SEC-DP1 | "Implement a strong identity foundation" | A least-privilege database role instead of the superuser |
| SEC-DP3 | "Apply security at all layers" | An internal backend network, a non-root API, no error details in responses |
| SEC-DP4 | "Automate security best practices" | Pinned images and an image gate with trivy and hadolint |

## 2. Summary

| Finding | Symptom | Root cause | Fix | Verified by |
|---|---|---|---|---|
| F1 | Every `/api/*` request returns 502 | nginx proxies to port 3001, the API listens on 3000 | `3464284` | S1 |
| F2 | The API exits when Postgres restarts | No `pool.on("error")` listener | `e056ab3` | S3 |
| F3 | The API still exits with a pool listener in place | `db.release()` is skipped when the query throws, and the leaked client has no listener | `e056ab3` | S3, S10 |
| F4 | A crashed API stays down | No restart policy | `df245d7` | S8 |
| F5 | 502 or a 14 s stall after the API is recreated | nginx resolves `api` once at startup | `3464284` | S6 |
| F6 | Requests hang while Postgres stalls | No connection timeout, no query timeout, nginx waits 60 s | `e056ab3` | S4 |
| F7 | A Redis outage turns every request into a 20 s failure | The Redis write is awaited on the request path with ioredis defaults | `d2b8f61` | S5, S12 |
| F8 | Connection exhaustion once the API scales | `max_connections = 20` in an unmounted `init.sql`, a pool of 10 per replica, the app logs in as superuser | `044aa1e` | S7 |
| F9 | Every stop is a kill after 10 s | Node runs as PID 1 without a SIGTERM handler | `df245d7` | S9 |
| F10 | No health signal, and the first requests race Postgres | No healthcheck, no readiness, `depends_on` without conditions | `df245d7` | S11, S12 |
| F11 | Outdated and unpinned images | Node 20 and nginx 1.25 past end of life, no lockfile, the API runs as root | `3464284`, `9f523dc` | Image gate |
| F12 | Hygiene | Credentials in code and compose, empty config files, `err.message` in responses, an anonymous data volume | `e056ab3`, `044aa1e` | Section 3 |

F0 is the control run: with every dependency healthy the endpoint handles 2313 requests/s with a p99 of 44 ms, so load is not the problem. F8 is dormant in the template, because nothing mounts `init.sql`, and wakes up as soon as someone mounts it or scales the API.

## 3. Diagnosis

### 3.1 Method

1. Reproduce: start the template untouched and call `/api/users` through nginx and directly on the API container.
2. Isolate one dependency at a time with `docker restart`, `docker pause` and `docker stop` on Postgres and Redis, under load from `ab` or k6, while reading the logs of nginx and the API.
3. Confirm each hypothesis with the smallest possible change, an override file that changes one thing, and check that the symptom disappears and nothing else changes.
4. Turn each confirmed fault into a scenario of `scripts/verify.sh`, run it on the template first and keep that run as the baseline.

`evidence/probes/README.md` lists the exact command and the observed output for every finding, and the override files it uses.

### 3.2 Findings

| ID | Evidence |
|---|---|
| F0 | Port fixed by a probe override: `ab -c 50 -n 5000` gave 0 failed, p99 44 ms, 2313 requests/s |
| F1 | nginx logs `connect() failed (111: Connection refused)` for upstream port 3001. A direct call on port 3000 returns `{"ok":true,...}` |
| F2 | `docker restart` on Postgres leaves the API `Exited (1)` with `Unhandled 'error' event` |
| F3 | With only `pool.on("error")` added, a Postgres restart under load logs query errors at `index.js:21`, then `read ECONNRESET` and `Emitted 'error' event on Client instance`, then the process exits |
| F4 | `RestartPolicy=no`. The API answers 502 until a manual `docker start` |
| F5 | The API moved from `.4` to `.6` and nginx kept `.4`: 3 of 3 requests failed until nginx restarted. With the old IP unassigned, each request waited about 14 s (`No route to host`) before the 502 |
| F6 | `docker pause` on Postgres: no response before the client gave up at 15.00 s |
| F7 | `docker stop` on Redis: HTTP 500 after 20.66 s |
| F8 | Unmounted, `max_connections` is 100. With `init.sql` mounted and 3 replicas: 39 of 20000 requests non-2xx with `sorry, too many clients already`, p99 1005 ms, and the admin `psql` refused |
| F9 | `docker stop` took 11 s and ended with exit code 137 |
| F10 | `health=none` on every container, and `/status` through nginx returns 404 |
| F11 | Runtime `v20.20.2`, `nginx/1.25.5`, an empty `Config.User`. Trivy findings in section 5.2 |
| F12 | Read from the source and from `docker inspect`: credentials in `index.js` and `docker-compose.yml`, empty `nginx/nginx.conf` and `.env`, the obsolete `version` key, Postgres data in the image's anonymous volume, so `docker compose down -v` deletes it |

### 3.3 Causal chain

A Postgres restart or an idle-connection kill crashes the API (F2, F3). Nothing restarts it (F4), and when it does come back with a new IP, nginx keeps sending traffic to the old one (F5). A slow dependency makes requests hang instead of failing fast (F6, F7). On top of that, F1 makes every `/api` request fail today.

## 4. Fixes

Each commit fixes one root cause, and `verify.sh` ran after each one. The evidence README lists the run per commit and explains every failure that the commit under test did not target.

| Commit | Change | Findings | ADR |
|---|---|---|---|
| `0c94285` | The failure-injection harness, probe overrides and the baseline runs | All | ADR-P3-0001, ADR-P3-0011 |
| `3464284` | nginx 1.30 with an `upstream` that re-resolves Docker DNS every 5 s, routes to port 3000, keeps connections alive, times out in 2 s and 10 s and retries once before a response starts | F1, F5, F11 | ADR-P3-0002 |
| `e056ab3` | One query helper with a 2 s deadline per request, `release(err)` on every error, a listener on checked-out clients, a 503 with `Retry-After` and a request ID instead of `err.message` | F2, F3, F6, F12 | ADR-P3-0003 |
| `d2b8f61` | The Redis write leaves the request path, with one write in flight, no offline queue and a 200 ms command timeout | F7 | ADR-P3-0004 |
| `df245d7` | Exit on fatal errors, `restart: unless-stopped`, `init: true`, an 8 s bounded shutdown, `/healthz`, `/readyz` on its own one-connection pool, healthchecks and `service_healthy` conditions, Redis outside readiness | F4, F9, F10 | ADR-P3-0005, ADR-P3-0006 |
| `044aa1e` | `max_connections=30` on the command line, a non-superuser `app` role with `CONNECTION LIMIT 25`, `PG*` variables with local-only defaults, an internal backend network, two replicas, resource limits, a named volume | F8, F12 | ADR-P3-0007, ADR-P3-0009, ADR-P3-0010 |
| `9f523dc` | Two-stage `node:24-alpine` build with a lockfile, no package manager at runtime, UID 1000, Postgres 15.19 and Redis 7.4 on Alpine, every image pinned by digest | F11 | ADR-P3-0008 |
| `230c3af` | Prometheus metrics, five alert rules with unit tests, a blackbox probe through nginx | Monitoring | ADR-P3-0012 |

The connection budget is `max_connections >= replicas x (PG_POOL_MAX + 1 readiness connection) + exporter connections + 5 for admin work + 3 reserved`. Two replicas need 18 and four need 28, so 30 covers scaling to four replicas and the `app` role limit of 25 keeps admin access free.

Health in Compose has limits. Compose uses healthchecks for startup order and status only, and never restarts a container that turns unhealthy. Liveness therefore comes from the process exiting on a fatal error and the restart policy bringing it back. Open-source nginx has passive health checks only: a replica is skipped for 5 s after one failed attempt, and a response that has started reaching the client cannot be retried.

## 5. Verification

### 5.1 Matched before and after runs

`scripts/verify.sh` runs every scenario under its own compose project with load from a pinned k6 image and Redis faults through a pinned Toxiproxy. `scripts/verify-before.sh` runs the same script, schedule and topology on the template, plus only the override a scenario needs to run at all: the port fix for every scenario except S1, and `init.sql` mounted for S7.

| ID | Scenario | Before (template) | After (`c031a5f`) |
|---|---|---|---|
| S1 | `GET /api/users` through nginx | HTTP 502 | HTTP 200 |
| S2 | 200 requests/s for 60 s, dependencies healthy | 12001 requests, 0 failed, p99 4.2 ms | 12001 requests, 0 failed, p99 5.2 ms |
| S3 | Postgres restarted 5 times under load | 0 of 2 replicas running after the first restart, 14541 to 16904 errors outside each outage window | 2 of 2 running, 0 restarts, outages of 456 to 758 ms, 0 errors outside any window |
| S4 | Postgres paused for 15 s under load | Slowest response 15004 ms, the client timeout | Slowest response 1906 ms, every response while paused a 503, 0 errors from 5 s after the unpause |
| S5 | Redis stopped, paused and blackholed | p99 15004 ms with 1332 to 1600 failed requests in each case | p99 3.3, 3.8 and 3.7 ms, 0 failed requests |
| S6 | Every API replica recreated while placeholders hold the old IPs | No 200 within 15 s, last answer 502 | First 200 after 32 ms |
| S7 | 4 replicas, 120 concurrent clients for 60 s | 4519 of 261407 requests failed with `too many clients`, admin `psql` refused | 588920 requests, 0 failed, app connections at most 20, admin `psql` works |
| S8 | `kill -9` on one of two replicas under load | No restart, the replica never rejoined | 0 of 2000 requests failed in the 10 s after the kill, 1 restart, rejoined after 6131 ms |
| S9 | `docker stop` on one replica, healthy and with Postgres paused | 10327 and 10232 ms, exit code 137 | 422 and 392 ms, exit code 0, no failed request during the stop |
| S10 | Pool health across the 5 faults of S3 | The API was down, fresh requests got 502 or no answer | Fresh request 200 after every fault, 0 clients in use or waiting, at most 5 Postgres and 1 Redis connections per replica, RSS within 10 % of the first cycle |
| S11 | Cold start, fresh and existing volume | HTTP 502 and 502 | HTTP 200 and 200 |
| S12 | Cold start with Redis scaled to 0 | HTTP 500 after 5766 ms | HTTP 200 after 39 ms |

The before runs are `evidence/verify-before-20261104-215042.md` and `evidence/verify-before-20261104-221004.md`, the second after three corrections to the harness that `evidence/README.md` explains. The after run is `evidence/verify-after-full-20261104-232524.md`, on `c031a5f`, whose code is the same as `9f523dc`.

### 5.2 Images

`scripts/image-gate.sh` scans the template and this stack with trivy 0.76.1 and one vulnerability database, and lints both Dockerfiles with hadolint 2.15.1.

| Image | Before (HIGH, CRITICAL) | After (HIGH, CRITICAL) |
|---|---|---|
| nginx | `nginx:1.25`: 176, 21 | `nginx:1.30-alpine`: 5, 1 |
| Postgres | `postgres:15`: 87, 2 | `postgres:15.19-alpine`: 25, 1 |
| Redis | `redis:7`: 32, 1 | `redis:7.4-alpine`: 0, 0 |
| API | Template build on `node:20-alpine`: 25, 1 | Two-stage build on `node:24-alpine`: 0, 0 |
| `api/Dockerfile` | hadolint: 0 findings | hadolint: 0 findings |

The full output with digests is `evidence/image-gate-20261104-234508.md`.

The 26 findings left in Postgres sit in the Go standard library compiled into `gosu`, which the entrypoint runs once to drop root. The 6 left in nginx sit in curl, libcurl, libexpat and brotli-libs. Both images are the newest builds of their tags today, so the fixes arrive with the next upstream rebuild and a digest bump (ADR-P3-0008).

## 6. Monitoring and alerts

`monitoring/` holds the Prometheus configuration, five alert rules and their `promtool` unit tests. `docker compose --profile monitoring up` starts Prometheus and a blackbox exporter next to the stack. `scripts/monitoring-check.sh` stops nginx and measures the alert end to end.

| Alert | Signal | Condition | Severity | Catches | State |
|---|---|---|---|---|---|
| ApiProbeFailing | Blackbox probe of `/api/users` through nginx | 2 consecutive failures, or the probe series absent | page | F1, F4, F5, any nginx-generated failure | implemented |
| Api5xxRatioHigh | API request histogram | 5xx above 1 % of `/api/users` over 5 min | page | F2 to F7 | implemented |
| PgPoolSaturated | Pool waiting gauge | above 0 for 2 min | ticket | F3, F6, F8 | implemented |
| ApiLatencyP99High | API request histogram | p99 above 100 ms for 10 min | ticket | F6, F7 | implemented |
| RedisWriteFailures | API counter | any failed write in 10 min | ticket | F7 in its degraded form | implemented |
| ApiRestarting | Container restart count | more than 2 in 10 min | page | F2, F3 | proposed |
| PostgresDown | `pg_up` from postgres_exporter | 0 for 1 min | page | Postgres outage | proposed |
| PgConnectionsHigh | Connections over `max_connections` | above 80 % for 5 min | ticket | F8 | proposed |
| CrashSignatureInLogs | Log query for `Unhandled 'error' event` and `too many clients` | any match | ticket | F2, F3, F8 | proposed |

Pages go out only for symptoms users feel, so Redis never pages. The proposed rows need telemetry that this compose stack does not have (container metrics, a Postgres exporter, a log store). In production the 5xx and latency alerts become multi-window burn-rate alerts on an availability SLO, assumed at 99.9 %. The runbook for each implemented alert is in `monitoring/README.md`.

`evidence/monitoring-check-20261104-234826.md` holds the end-to-end run on `230c3af`: the three scrape targets came up within 2.1 s, `ApiProbeFailing` fired 43.1 s after nginx stopped and cleared 28.0 s after it started again. Scrape and evaluation both run every 15 s and the rule waits 15 s, so the delay depends on where the stop falls in those cycles. An earlier run of the same check measured 23.8 s and 13.5 s. The S1, S2 and S8 run on the same commit (`evidence/verify-after-b1-20261104-235007.md`) shows no cost from the metrics: p99 3.9 ms at 200 requests/s.

## 7. Prevention in production

- Run the API on an orchestrator with liveness and readiness probes, at least two replicas across zones and a disruption budget, so one crash never becomes an outage.
- Use RDS or Aurora behind RDS Proxy for pooling and faster failover, and ElastiCache for Redis.
- Give every network call a total deadline and a bounded retry. Library defaults caused F6 and F7, so code review checks the `pg`, ioredis and nginx settings explicitly.
- Run contract checks in CI: `docker compose config`, `nginx -t`, a test that the nginx upstream port and the API listen port come from one variable, hadolint, trivy and `npm audit`.
- Run the failure scenarios S3 to S10 in CI on every change to the stack. Only failure injection would have caught F2 to F7 before users did.
- Pin images by digest, let Renovate or Dependabot raise updates, and track end-of-life dates so an unsupported runtime cannot reach production again.
- Define SLOs with error-budget alerts, link a runbook from every alert, and write a blameless postmortem for this incident.

## 8. Assumptions and what was left out

| Assumption | Why | If wrong |
|---|---|---|
| Nothing reads the Redis key `last_call` | No code in the repo reads it | A reader with a freshness need reopens ADR-P3-0004 |
| The stack is a local or single-host deployment | The template is Docker Compose with one published port | Section 7 describes the production target |
| Default credentials only need to keep strangers off an internal network | Postgres and Redis are not published, and the backend network is internal | Production takes credentials from a secret manager |

Left out: Kubernetes manifests (section 7 describes the target instead), PgBouncer (RDS Proxy covers pooling in production, and the budget covers 2 to 4 replicas), active health checks in nginx (they need NGINX Plus or another proxy), Grafana dashboards, and a Postgres major upgrade, which is a data migration that fixes none of the reported symptoms.

## 9. Traceability

| Decision | Requirements | Principles | Verified by | ADR |
|---|---|---|---|---|
| nginx upgrade, upstream with `resolve`, timeouts, retry | REQ-P3-2, REQ-P3-3, REQ-P3-5 | REL-DP1, REL-DP3 | S1, S6, S8 | ADR-P3-0002 |
| Query helper with one deadline | REQ-P3-2, REQ-P3-3 | REL-DP1, OPS-DP6 | S3, S4, S10 | ADR-P3-0003 |
| Redis write off the request path | REQ-P3-2, REQ-P3-3 | REL-DP1, OPS-DP6 | S5, S12 | ADR-P3-0004 |
| Crash-only exit, restart policy, bounded shutdown | REQ-P3-2 | REL-DP1, OPS-DP6 | S8, S9 | ADR-P3-0005 |
| Liveness, readiness, dependency conditions | REQ-P3-2, REQ-P3-5 | OPS-DP2, REL-DP1 | S10, S11, S12 | ADR-P3-0006 |
| Connection budget and `app` role | REQ-P3-2, REQ-P3-3 | REL-DP4, GEN-DP1, SEC-DP1 | S7, S11 | ADR-P3-0007 |
| Current runtimes, pinned digests | REQ-P3-4 | SEC-DP4, SEC-DP3 | Image gate | ADR-P3-0008 |
| Two replicas and an internal network | REQ-P3-2 | REL-DP3, SEC-DP3 | S3, S8 | ADR-P3-0009 |
| Local-only default credentials | REQ-P3-5 | SEC-DP1, SEC-DP3 | S11 | ADR-P3-0010 |
| Failure-injection harness | REQ-P3-1, REQ-P3-3 | REL-DP2, GEN-DP6 | Matched before and after runs | ADR-P3-0001, ADR-P3-0011 |
| Metrics, probe and alert rules | REQ-P3-4 | OPS-DP2, OPS-DP7 | `promtool` tests, monitoring check | ADR-P3-0012 |
