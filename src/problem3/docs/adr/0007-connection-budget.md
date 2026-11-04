# ADR-P3-0007: Explicit Postgres connection budget with a least-privilege role

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-2, REQ-P3-3 |
| Principles | REL-DP4, GEN-DP1, SEC-DP1 |
| Supersedes | none |

## Context

`init.sql` sets `max_connections = 20` through `ALTER SYSTEM` but is never mounted. Mounted, three replicas with the default pool of 10 need 30 connections: 39 of 20000 requests failed with `sorry, too many clients already`, and admin `psql` was refused because the app logs in as the superuser and uses the reserved slots too (F8).

## Decision

`max_connections=30` is set on the command line of the Postgres container. The API logs in as a non-superuser `app` role with `CONNECTION LIMIT 25`, created by an init script, and each replica uses 4 pool connections plus 1 for readiness. The budget is `replicas x 5 + exporters + 5 for admin work + 3 reserved`, which fits four replicas.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Raise `max_connections` to 100 or more | One number | Hides the next leak, each connection costs server memory | Treats the symptom |
| PgBouncer in front of Postgres | Multiplexes many clients onto few connections | Another component, transaction pooling breaks session features | Not needed at 2 to 4 replicas, RDS Proxy plays this role in production |
| Keep the superuser | No init script | Reserved slots stop protecting admin access, full privileges for the app | Fails SEC-DP1 and F8 |
| Keep `ALTER SYSTEM` in `init.sql` | Matches the template | The value hides in `postgresql.auto.conf`, applied only on a fresh volume | Configuration nobody sees in review |

## Trade-offs

Scaling past four replicas needs a deliberate budget change, which is the point of REL-DP4. The init script runs only on an empty data directory, so an older volume needs `docker compose down -v` once.

## Consequences

### Positive

- Admin access survives saturation because the app cannot use the superuser slots.
- The connection limit is visible in `docker-compose.yml` and in the role definition.

### Negative

- One more file (`postgres/initdb/10-app-role.sh`) to keep in sync with the compose environment.

### Risks

- A new client of the database could exceed the budget. The `pg_stat_activity` check in S7 and the connection alert in the monitoring plan detect it.

## Verification

S7 with four replicas and 120 concurrent clients in a closed loop, and S11 with a fresh and an existing volume (local run).

## Reopen when

The API needs more than four replicas or more than 20 concurrent database sessions, which points to RDS Proxy or PgBouncer.
