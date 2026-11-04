# Monitoring

The API exposes Prometheus metrics on `/metrics` at port 3000. nginx does not route that path, so only the compose networks reach it. The `monitoring` profile adds Prometheus and a blackbox exporter and leaves the default stack unchanged.

```bash
docker compose --profile monitoring up -d --build --wait
```

Prometheus listens on `127.0.0.1:9090`. It discovers the API replicas through Docker DNS and probes `/api/users` through nginx every 15 s.

| Metric | Type | Labels |
|---|---|---|
| `http_request_duration_seconds` | Histogram | `route` (template or `other`), `method`, `status_class` |
| `pg_pool_clients` | Gauge | `state` (`total`, `idle`) |
| `pg_pool_waiting_requests` | Gauge | none |
| `redis_write_failures_total` | Counter | none |
| `probe_success` | Gauge from the blackbox exporter | `instance` |

`scripts/test-alerts.sh` runs the rule unit tests with `promtool`. `scripts/monitoring-check.sh --yes` starts the profile, stops nginx and measures how long `ApiProbeFailing` takes to fire and to clear.

## Runbook

### ApiProbeFailing

Users cannot reach `/api/users`. Check `docker compose ps` for nginx and the API, then `docker compose logs --tail 50 nginx`. A 502 with `connect() failed` points to the API replicas, a refused connection on port 8080 points to nginx itself. The alert also fires when the probe stops reporting, which means Prometheus or the blackbox exporter is down.

### Api5xxRatioHigh

More than 1 % of `/api/users` responses are 5xx. Read the `error` field of the API's JSON logs: `dependency_unavailable` and `dependency_timeout` mean Postgres refused or stalled, `internal_error` means a bug. Compare with `pg_pool_waiting_requests` and the Postgres container state.

### PgPoolSaturated

Requests queue for a database client. A slow Postgres, a leaked client or more load than 4 connections per replica can serve all show here. Check `/internal/pool` on each replica and `pg_stat_activity` for long-running queries before raising `PG_POOL_MAX`, and keep the connection budget of ADR-P3-0007.

### ApiLatencyP99High

The p99 of `/api/users` stayed above 100 ms for 10 minutes. Postgres latency is the usual cause, because the endpoint makes one query and Redis is off the request path. Check the pool gauges and the Postgres container's CPU limit.

### RedisWriteFailures

Writes of `last_call` failed. Responses are not affected, because the write is off the request path. Check `docker compose ps redis` and the API's `redis write failed` log lines. Redis never pages, since users do not feel it.
