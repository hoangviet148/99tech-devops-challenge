# ADR-P3-0006: Separate liveness and readiness, Redis outside readiness

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-2, REQ-P3-5 |
| Principles | OPS-DP2, REL-DP1 |
| Supersedes | none |

## Context

No service has a healthcheck, `depends_on` has no condition, and `/status` answers 200 without checking anything (F10). Compose uses healthchecks for startup ordering and for `docker compose up --wait`, and it waits for every service that defines one. Redis is optional after ADR-P3-0004.

## Decision

`/healthz` reports that the process is alive. `/readyz` runs `SELECT 1` through a dedicated pool of one connection bounded to 500 ms, with concurrent probes sharing one check. nginx, the API and Postgres get healthchecks, nginx waits for a healthy API, the API waits for a healthy Postgres, and nothing waits for Redis, which has no healthcheck. `/internal/pool` exposes pool counters to the harness and nginx does not route it.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| One `/status` endpoint that checks everything | One URL | Mixes "restart me" with "do not route to me" | Liveness and readiness need different answers |
| Readiness that includes Redis | Reports every dependency | An outage of an optional cache makes every replica unready, which is a full outage | Turns a degraded state into downtime |
| Readiness through the main pool | No extra connection | Probes queue behind traffic and flap under saturation | Health would fail exactly when the pool is busy |

## Trade-offs

Each replica holds one more Postgres connection, which the budget in ADR-P3-0007 counts. `/internal/pool` is reachable by anything on the edge network, which is acceptable for a local stack and would sit behind a network policy in production.

## Consequences

### Positive

- `docker compose up --wait` returns only when the stack can serve.
- The stack starts and serves with Redis absent (S12).

### Negative

- Readiness does not report a Redis outage, so that signal moves to the write-failure counter.

### Risks

- A readiness probe that passes while the main pool is exhausted. The pool waiting gauge in the monitoring plan covers that gap.

## Verification

S10, S11 and S12 in `scripts/verify.sh` (local run).

## Reopen when

An orchestrator starts routing traffic on readiness, which calls for a separate degraded-mode signal for Redis.
