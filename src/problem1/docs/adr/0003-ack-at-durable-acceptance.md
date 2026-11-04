# ADR-P1-0003: No database call on the order path, acknowledgement at durable acceptance

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-7, REQ-P1-8, REQ-P1-14A |
| Principles | PERF-DP5, GEN-DP5 |
| Supersedes | none |

## Context

REQ-P1-8 asks for a p99 under 100 ms measured through CloudFront and WAF, and the edge, the ALB and the gateway already take 20 ms of the allocation. A balance check in the database adds a round trip and a row lock on every order, and hot accounts such as market makers serialize on that lock. The risk engine holds balances in memory per account shard (ADR-P1-0004). `SOLUTION.md` tracks this record as AD-P1-02.

## Decision

The order service validates the order, the risk writer computes the reservation in memory, and both are written in one Kafka transaction with `acks=all` across 3 AZs. The client gets its acknowledgement when that transaction commits (t1), and matching (t2) and the ledger commit (t3) follow asynchronously.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Reserve funds with `SELECT ... FOR UPDATE` on the balance row | The database is the only truth, simple to reason about | A database round trip and a lock per order, the Aurora writer on the order path | Lock contention on hot accounts and a writer bottleneck against REQ-P1-7 at 3x |
| Acknowledge from memory and persist later | Lowest latency | An acknowledged order is lost when the process dies before the write | Breaks REQ-P1-13A and REQ-P1-14A |
| Reservations as DynamoDB conditional writes | Managed, low latency | A second system of record for balances next to the ledger | Two truths to reconcile for every order |

## Trade-offs

The ledger lags the risk engine. A credit becomes spendable only after the ledger commit, so settlement speed (REQ-P1-16A) decides how fast proceeds can be reused, and the settlement lag rule of section 4.1 bounds exposure when the ledger falls behind.

## Consequences

### Positive

- The order path has 40 ms of unallocated budget, 38 ms after SC-04 in Problem 5.
- An acknowledged order is durable in 3 AZs, so a failover loses none.

### Negative

- Balances shown to users come from the risk engine for available and reserved amounts, and from the ledger for settled history, so the UI explains pending amounts.

### Risks

- MSK produce latency drives the order path. The load test reports it per hop, and AD-P1-20 benchmarks the alternatives.

## Verification

k6 at 500 rps and on the 1500 rps plateau through the public hostname, per request class (cloud run).

## Reopen when

The load test shows order placement p99 above 100 ms with the MSK produce hop above its 30 ms allocation.
