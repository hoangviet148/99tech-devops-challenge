# ADR-P1-0011: ElastiCache for Valkey for rate limits and market data, with a local fallback

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-8, REQ-P1-15A |
| Principles | REL-DP1, OPS-DP8 |
| Supersedes | none |

## Context

Per-key rate limits must hold across all gateway pods, or a client multiplies its limit by the pod count. The market data service needs depth snapshots that many WebSocket pods read. Both are derived data that can be rebuilt, and a cache outage must not stop trading. REQ-P1-15A allows up to 1 % of requests to be shed with 429 for at most 5 min while autoscaling converges. `SOLUTION.md` tracks this record as AD-P1-11.

## Decision

ElastiCache for Valkey runs one primary and two replicas across 3 AZs for rate limit counters and depth snapshots. When Valkey is unreachable, each gateway pod falls back to local token buckets, and the gateway sheds load with 429 above its capacity.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| MemoryDB | Durable writes | Higher write latency and cost | Derived data does not need durability |
| Local rate limits only | No shared dependency | A client gets the limit once per pod | Limits stop meaning anything at scale |
| DynamoDB counters | Serverless, durable | A write per request at 500 rps and more | Cost and latency for data that can be lost |

## Trade-offs

During a Valkey failover the local fallback allows up to the per-pod limit on every pod, so a client can briefly exceed its global limit. Up to 1 % of requests get 429 during the ramp to 3x, as REQ-P1-15A allows.

## Consequences

### Positive

- A cache outage degrades rate limiting and market data freshness without stopping orders.
- Market data clients detect gaps by sequence number and resync after a failover.

### Negative

- Rate limits are approximate during failover.

### Risks

- The nonce store of SC-04 in Problem 5 also lives in Valkey, and a failover can lose the newest nonces. Orders then rely on the durable client order ID and withdrawals fail closed, as SC-04 defines.

## Verification

Load test with the 5 min ramp to the 1500 rps plateau, reporting the 429 share and its duration (cloud run).

## Reopen when

Shedding exceeds 1 % of requests or lasts longer than 5 min in a load test or in production.
