# ADR-P1-0011: ElastiCache for Valkey for rate limits and market data, with a local fallback

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-8, REQ-P1-15A |
| Principles | REL-DP1, OPS-DP8 |
| Supersedes | none |

## Context

Per-key rate limits must hold across all gateway pods, or a client multiplies its limit by the pod count. The market data service needs depth snapshots that many WebSocket pods read. Both are derived data that can be rebuilt, and a cache outage must not stop trading. Above static capacity an exchange must still let clients cancel, because a client that cannot leave the book during volatility carries risk it did not choose. A cancel acknowledged at t1 only takes effect when matching commits it at t2. REQ-P1-15A allows up to 1 % of requests to be shed with 429 for at most 5 min while autoscaling converges. `SOLUTION.md` tracks this record as AD-P1-11 and the managed-service part of AD-P1-08, with the policy in section 4.6.

## Decision

ElastiCache for Valkey runs one primary and two replicas across 3 AZs for rate limit counters and depth snapshots, and each gateway pod falls back to local token buckets when Valkey is unreachable. Above capacity every shed request gets 429 with a jittered Retry-After, in a fixed order: new WebSocket connections and reconnects, public market data misses, private reads, new orders, and cancels last. Each risk shard rejects new orders while its in-flight commit has been open for longer than the 68 ms that REQ-P1-8 leaves after the other hops, minus the measured commit p99, and cancels, which keep a reserved lane with their own rate bucket, are never rejected by this slow-commit rule.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| MemoryDB | Durable writes | Higher write latency and cost | Derived data does not need durability |
| Local rate limits only | No shared dependency | A client gets the limit once per pod | Limits stop meaning anything at scale |
| DynamoDB counters | Serverless, durable | A write per request at 500 rps and more | Cost and latency for data that can be lost |
| One queue and one rate bucket for orders and cancels | Simpler gateway and risk writer | A burst of new orders delays cancels and sheds them with the orders | Clients could not leave the book during volatility |

## Trade-offs

During a Valkey failover the local fallback allows up to the per-pod limit on every pod, so a client can briefly exceed its global limit. Up to 1 % of requests get 429 during the ramp to 3x, as REQ-P1-15A allows. OPS-DP8 is served by the managed cache, and the fixed shedding order serves REL-DP1 by keeping cancels working while the platform is saturated.

## Consequences

### Positive

- A cache outage degrades rate limiting and market data freshness without stopping orders.
- Market data clients detect gaps by sequence number and resync after a failover.
- Cancels keep working while new orders are shed.

### Negative

- Rate limits are approximate during failover.
- A cancel acknowledged at t1 can still meet a fill before t2, so clients read the final state from the order stream or the order query.

### Risks

- The nonce store of Problem 5 SC-04 also lives in Valkey, and a failover can lose the newest nonces. Orders then rely on the durable client order ID and withdrawals fail closed, as Problem 5 SC-04 defines.

## Verification

Load test with the 5 min ramp to the 1500 rps plateau, reporting the 429 share and its duration, and a step test from 500 to 2,500 rps in 30 s with a reconnect wave of 10,000 WebSocket connections, checking the shedding order and that cancels are shed last (cloud run).

## Reopen when

Shedding exceeds 1 % of requests or lasts longer than 5 min in a load test or in production, or a cancel is rejected by the slow-commit rule.
