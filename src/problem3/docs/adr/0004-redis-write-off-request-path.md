# ADR-P3-0004: The Redis write leaves the request path

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-2, REQ-P3-3 |
| Principles | REL-DP1, OPS-DP6 |
| Supersedes | none |

## Context

Every request awaits `redis.set("last_call", ...)` with ioredis defaults: an offline queue and 20 reconnection attempts per command. With Redis stopped, each request failed with 500 after 20.66 s (F7). Nothing in the repo reads `last_call`, so the write is bookkeeping, and the endpoint's answer does not depend on it.

## Decision

The handler never awaits the write. At most one write per process is in flight, a newer timestamp replaces a pending one, the offline queue is off and `commandTimeout` is 200 ms. Failures increment a counter, and connection and command errors log at a capped rate.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Await the write with a short timeout | Keeps the write in the request | A paused or blackholed Redis still adds up to 200 ms per request | Breaks the 100 ms p99 target in S5 |
| Remove Redis from the stack | Simplest | Changes product behaviour without knowing who relies on `last_call` | Too large an assumption for a stabilization task |
| Queue or outbox the write durably | No lost updates | A queue for a timestamp nobody reads | Cost far above the value of the data |

## Trade-offs

`last_call` can be stale or missing while Redis is down, so durability of that value is traded for availability of the endpoint. The report states the assumption that nothing reads it.

## Consequences

### Positive

- A stopped, paused or blackholed Redis no longer affects responses.
- Redis becomes optional at startup (ADR-P3-0006).

### Negative

- Write failures are only visible through the counter and the logs.

### Risks

- A reader of `last_call` may exist outside the repo. The assumption is called out in `SOLUTION.md` so a reviewer can challenge it.

## Verification

S5 with Redis stopped, paused and blackholed through Toxiproxy, and S12 with Redis scaled to zero (local run).

## Reopen when

A consumer of `last_call` appears with a freshness requirement.
