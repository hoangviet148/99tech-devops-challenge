# ADR-P3-0003: One absolute deadline per request for database work

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-2, REQ-P3-3 |
| Principles | REL-DP1, OPS-DP6 |
| Supersedes | none |

## Context

The handler checks out a client and skips `release()` when the query throws (F3). The leaked client later emits a socket error with no listener and kills the process, and idle client errors do the same because the pool has no listener (F2). No timer bounds the work: with Postgres paused, requests hung until the client gave up at 15 s (F6). `pg` 8.23.1 accepts `query_timeout` per query, and `pg-pool` applies `connectionTimeoutMillis` both to waiting for a client and to opening one.

## Decision

A single helper gives each request a 2 s deadline: acquisition bounded at 1 s by the pool, `query_timeout` set to the remaining time minus 100 ms, server-side `statement_timeout` at 1 s, the client destroyed with `release(err)` on any error, an error listener while it is checked out, and a backstop timer that answers 503 with `Retry-After` and drops any late result.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| `pool.query()` with static timeouts | Least code, release handled by `pg` | Acquisition and query timers add up to 2.5 s, no single budget | Cannot express a request deadline |
| Server-side `statement_timeout` only | One setting | Does nothing when the server is paused or unreachable, the case of F6 | Misses the failure that was observed |
| Circuit breaker library such as opossum | Fails fast after repeated errors | A new dependency with its own state, and it still needs per-call timeouts | Worth it with several dependencies, not with one query |
| `AbortController` cancellation | Standard API | `pg` cannot abort an in-flight query, destroying the client is the only cancellation | Not supported by the driver |

## Trade-offs

During a short database blip users get a fast 503 instead of a slow success. REL-DP1 favours failing fast and letting clients retry. The 2 s budget is an assumption, since the challenge states no latency objective for this endpoint.

## Consequences

### Positive

- Latency is bounded during every database fault reproduced so far (S3, S4).
- No client can leak or crash the process (F2, F3).

### Negative

- The handler carries timer and guard logic that a framework would otherwise hide.
- Under saturation the 1 s acquisition bound sheds load rather than queueing it.

### Risks

- A future slow query would hit the 1 s statement timeout. The 503 rate alert in section 5.6 of the plan makes that visible.

## Verification

S3, S4 and S10 in `scripts/verify.sh` (local run).

## Reopen when

The endpoint gets a stated latency objective, or a route needs queries longer than 1 s and therefore a budget of its own.
