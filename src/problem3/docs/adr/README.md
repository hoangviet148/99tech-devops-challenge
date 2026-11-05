# Problem 3 architecture decision records

Each record follows the format in `template.md`: context, decision, alternatives with their trade-offs, consequences, verification and the trigger that would reopen it. Requirement and principle IDs refer to the plan's register.

| ADR | Decision | Status | Date |
|---|---|---|---|
| [ADR-P3-0001](0001-isolated-fault-injection.md) | Diagnose by isolated fault injection and fix one root cause per commit | accepted | 2026-11-04 |
| [ADR-P3-0002](0002-nginx-upstream-resolve.md) | nginx 1.30 with an upstream that re-resolves Docker DNS | accepted | 2026-11-04 |
| [ADR-P3-0003](0003-request-deadline.md) | One absolute deadline per request for database work | accepted | 2026-11-04 |
| [ADR-P3-0004](0004-redis-write-off-request-path.md) | The Redis write leaves the request path | accepted | 2026-11-04 |
| [ADR-P3-0005](0005-crash-only-restart.md) | Crash-only process with a restart policy and a bounded shutdown | accepted | 2026-11-04 |
| [ADR-P3-0006](0006-liveness-readiness.md) | Separate liveness and readiness, Redis outside readiness | accepted | 2026-11-04 |
| [ADR-P3-0007](0007-connection-budget.md) | Explicit Postgres connection budget with a least-privilege role | accepted | 2026-11-04 |
| [ADR-P3-0008](0008-runtime-and-image-policy.md) | Current LTS runtimes, pinned digests, Postgres major kept | accepted | 2026-11-04 |
| [ADR-P3-0009](0009-replicas-and-networks.md) | Two API replicas and an internal backend network | accepted | 2026-11-04 |
| [ADR-P3-0010](0010-local-only-default-credentials.md) | Local-only default credentials so the stack starts with one command | accepted | 2026-11-04 |
| [ADR-P3-0011](0011-failure-injection-harness.md) | Failure-injection harness in bash with k6 and Toxiproxy | accepted | 2026-11-04 |
| [ADR-P3-0012](0012-metrics-and-alert-rules.md) | Prometheus metrics, a probe through nginx and tested alert rules | accepted | 2026-11-04 |
