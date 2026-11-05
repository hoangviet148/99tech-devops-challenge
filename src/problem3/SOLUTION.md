# Problem 3: an unreliable API on Docker Compose

The stack is nginx in front of a Node.js API that reads Postgres and writes Redis. The API is fast while every dependency is healthy. It fails hard and stays down when a dependency blips, and a port typo breaks every `/api` request on the template.

```bash
docker compose up --build
curl -s http://localhost:8080/api/users
```

A volume left by an earlier version of this stack needs `docker compose down -v` once. The init script that creates the database role runs only on an empty data directory.

## 1. Problems found

| ID | Symptom | Root cause |
|---|---|---|
| F0 | None in the control run with the port fixed: 2313 requests/s, p99 44 ms | Load is not the problem |
| F1 | Every `/api/*` request returns 502 | nginx proxies to port 3001, the API listens on 3000 |
| F2 | The API exits when Postgres restarts | No `pool.on("error")` listener |
| F3 | The API still exits once a pool listener is added | `db.release()` is skipped when the query throws, and the leaked client has no listener |
| F4 | A crashed API stays down | No restart policy |
| F5 | 502, or a 14 s stall, after the API is recreated | nginx resolves `api` once at startup and keeps the old IP |
| F6 | Requests hang while Postgres stalls | No connection or query timeout, and nginx waits 60 s |
| F7 | A Redis outage turns every request into a 20 s failure | The Redis write is awaited on the request path with ioredis defaults |
| F8 | `too many clients` once the API scales | `max_connections = 20` in an unmounted `init.sql`, a pool of 10 per replica, and the app logs in as superuser |
| F9 | Every stop is a kill after 10 s | Node runs as PID 1 without a SIGTERM handler |
| F10 | No health signal, and the first requests race Postgres | No healthcheck, no readiness, `depends_on` without conditions |
| F11 | Outdated and unpinned images | Node 20 and nginx 1.25 past end of life, no lockfile, the API runs as root |
| F12 | Hygiene | Credentials in code and compose, empty config files, `err.message` in responses, Postgres data in an anonymous volume |

The causal chain is short. A Postgres restart or an idle-connection kill crashes the API (F2, F3). Nothing restarts it (F4). When it does come back with a new IP, nginx keeps sending traffic to the old one (F5). A slow dependency makes requests hang instead of failing fast (F6, F7). F1 sits on top and breaks every request on the template. F8 is dormant on the template and wakes up as soon as someone mounts `init.sql` or scales the API.

## 2. Diagnosis

I called `/api/users` on the untouched template through nginx and directly on the API container, which isolated F1. Then I broke one dependency at a time with `docker restart`, `docker pause` and `docker stop` under load from `ab` or k6, reading the nginx and API logs. Each hypothesis got an override file that changes one thing, and counted as confirmed only when the symptom disappeared and nothing else moved. Every confirmed fault became a `scripts/verify.sh` scenario, run on the template first as the baseline.

The exact command, the observed output and the override file for each finding are in [`evidence/probes/README.md`](evidence/probes/README.md). The method is [ADR-P3-0001](docs/adr/0001-isolated-fault-injection.md).

## 3. Fixes

One commit per root cause, each followed by a `verify.sh` run. [`evidence/README.md`](evidence/README.md) lists the run per commit and explains every failure outside the commit's target.

| Commit | Change | Fixes | ADR |
|---|---|---|---|
| `0c94285` | Failure-injection harness, probe overrides, baseline runs | All | ADR-P3-0001, ADR-P3-0011 |
| `3464284` | nginx 1.30, an `upstream` on port 3000 that re-resolves Docker DNS every 5 s, keepalive, 2 s and 10 s timeouts, one retry before the response starts | F1, F5, F11 | ADR-P3-0002 |
| `e056ab3` | One query helper with a 2 s deadline per request, `release(err)` on every error, a listener on checked-out clients, a 503 with `Retry-After` and a request ID instead of `err.message` | F2, F3, F6, F12 | ADR-P3-0003 |
| `d2b8f61` | The Redis write leaves the request path, with one write in flight, no offline queue and a 200 ms timeout | F7 | ADR-P3-0004 |
| `df245d7` | Exit on fatal errors, `restart: unless-stopped`, `init: true`, an 8 s bounded shutdown, `/healthz` and `/readyz`, healthchecks with `service_healthy`, Redis outside readiness | F4, F9, F10 | ADR-P3-0005, ADR-P3-0006 |
| `044aa1e` | `max_connections=30`, a non-superuser `app` role capped at 25, `PG*` variables with local-only defaults, an internal backend network, two replicas, resource limits, a named volume | F8, F12 | ADR-P3-0007, ADR-P3-0009, ADR-P3-0010 |
| `9f523dc` | Two-stage `node:24-alpine` build with a lockfile, UID 1000, Postgres 15.19 and Redis 7.4 on Alpine, every image pinned by digest | F11 | ADR-P3-0008 |
| `230c3af` | Prometheus metrics, five alert rules with unit tests, a blackbox probe through nginx | Monitoring | ADR-P3-0012 |

The connection budget in ADR-P3-0007 fits four replicas and keeps admin access free. Compose never restarts an unhealthy container, so liveness comes from exiting on a fatal error and the restart policy. Open-source nginx skips a failed replica for 5 s and cannot retry a response that has started.

## 4. Verification

`scripts/verify.sh` runs each scenario in its own compose project, with load from pinned k6 and Redis faults through pinned Toxiproxy. `scripts/verify-before.sh` runs it on the template with only the override a scenario needs: the port fix for all but S1, and `init.sql` mounted for S7.

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

Before runs: [`verify-before-20261104-215042.md`](evidence/verify-before-20261104-215042.md) and [`verify-before-20261104-221004.md`](evidence/verify-before-20261104-221004.md), the second after three harness corrections. After run: [`verify-after-full-20261104-232524.md`](evidence/verify-after-full-20261104-232524.md). Commit `c031a5f` only adds evidence on top of `9f523dc`.

`scripts/image-gate.sh` scans both stacks with trivy and lints both Dockerfiles with hadolint, which finds nothing. Output with digests: [`image-gate-20261104-234508.md`](evidence/image-gate-20261104-234508.md).

| Image | Before (HIGH, CRITICAL) | After (HIGH, CRITICAL) |
|---|---|---|
| nginx | `nginx:1.25`: 176, 21 | `nginx:1.30-alpine`: 5, 1 |
| Postgres | `postgres:15`: 87, 2 | `postgres:15.19-alpine`: 25, 1 |
| Redis | `redis:7`: 32, 1 | `redis:7.4-alpine`: 0, 0 |
| API | `node:20-alpine` template build: 25, 1 | `node:24-alpine` two-stage build: 0, 0 |

The findings left in nginx and Postgres sit in upstream packages and close with the next rebuild and a digest bump (ADR-P3-0008).

## 5. Monitoring and alerts

`docker compose --profile monitoring up` starts Prometheus and a blackbox exporter next to the stack. The rules and their `promtool` tests are in `monitoring/`, and each implemented alert has a runbook in [`monitoring/README.md`](monitoring/README.md).

| Alert | Condition | Severity | Catches | State |
|---|---|---|---|---|
| ApiProbeFailing | Blackbox probe of `/api/users` through nginx fails twice, or the series is absent | page | F1, F4, F5, any nginx-generated failure | implemented |
| Api5xxRatioHigh | 5xx above 1 % of `/api/users` over 5 min | page | F2 to F7 | implemented |
| PgPoolSaturated | Pool waiting gauge above 0 for 2 min | ticket | F3, F6, F8 | implemented |
| ApiLatencyP99High | p99 above 100 ms for 10 min | ticket | F6, F7 | implemented |
| RedisWriteFailures | Any failed Redis write in 10 min | ticket | F7 in its degraded form | implemented |
| ApiRestarting | More than 2 container restarts in 10 min | page | F2, F3 | proposed |
| PostgresDown | `pg_up` from postgres_exporter is 0 for 1 min | page | Postgres outage | proposed |
| PgConnectionsHigh | Connections above 80 % of `max_connections` for 5 min | ticket | F8 | proposed |
| CrashSignatureInLogs | Log match on `Unhandled 'error' event` or `too many clients` | ticket | F2, F3, F8 | proposed |

Only symptoms users feel can page, so Redis never pages. The proposed rows need container metrics, a Postgres exporter and a log store. In production the 5xx and latency alerts become multi-window burn-rate alerts on an availability SLO, assumed at 99.9 %.

`scripts/monitoring-check.sh` stops nginx and times the alert end to end. On `230c3af` it fired after 43.1 s and cleared 28.0 s after nginx came back ([`monitoring-check-20261104-234826.md`](evidence/monitoring-check-20261104-234826.md)). The delay depends on where the stop falls in the 15 s scrape and evaluation cycles. The metrics cost nothing measurable: p99 stayed at 3.9 ms at 200 requests/s ([`verify-after-b1-20261104-235007.md`](evidence/verify-after-b1-20261104-235007.md)).

## 6. Prevention in production

- Run the API on an orchestrator with liveness and readiness probes, at least two replicas across zones and a disruption budget, so one crash never becomes an outage.
- Use RDS or Aurora behind RDS Proxy for pooling and faster failover, and ElastiCache for Redis.
- Give every network call a total deadline and a bounded retry. Library defaults caused F6 and F7, so code review checks the `pg`, ioredis and nginx settings explicitly.
- Fail CI on contract breaks: `docker compose config`, `nginx -t`, a test that the nginx upstream port and the API listen port come from one variable, hadolint, trivy and `npm audit`.
- Run the failure scenarios S3 to S10 in CI on every stack change. Only failure injection catches F2 to F7 before users do.
- Pin images by digest, let Renovate or Dependabot raise updates, and track end-of-life dates.
- Define SLOs with error-budget alerts, link a runbook from every alert, and write a blameless postmortem for this incident.

## 7. Assumptions and what was left out

Nothing reads the Redis key `last_call`, because no code in the repo does. A reader that needs fresh values would reopen ADR-P3-0004. The stack is a local or single-host deployment, so the default credentials only keep strangers off an internal network. Production takes them from a secret manager (ADR-P3-0010).

Left out: Kubernetes manifests, since section 6 describes the target. PgBouncer, because RDS Proxy pools in production. Active nginx health checks, which need NGINX Plus. Grafana dashboards. A Postgres major upgrade, a data migration that fixes none of the symptoms.

## 8. Traceability

| Requirement | Where it is met | ADR |
|---|---|---|
| REQ-P3-1 Identify the issues | Sections 1 and 2, probes README | ADR-P3-0001, ADR-P3-0011 |
| REQ-P3-2 Fix them | Section 3, verified in section 4 | ADR-P3-0002 to ADR-P3-0010 |
| REQ-P3-3 Explain the root causes | Section 1 | ADR-P3-0002, ADR-P3-0003, ADR-P3-0004, ADR-P3-0007 |
| REQ-P3-4 Report diagnosis, fixes, monitoring and prevention | Sections 1 to 6 | ADR-P3-0008, ADR-P3-0012 |
| REQ-P3-5 `docker compose up --build` serves on port 8080 | Scenarios S1 and S11 | ADR-P3-0006, ADR-P3-0010 |
