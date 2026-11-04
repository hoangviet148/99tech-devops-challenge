# ADR-P1-0004: Risk engine with one writer per account shard

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-14A, REQ-P1-2 |
| Principles | REL-DP1, PERF-DP5 |
| Supersedes | none |

## Context

Orders, fills, cancels, deposits and withdrawals all change the same balances, and REQ-P1-14A forbids a spendable balance below zero. ADR-P1-0003 keeps the database off the order path, so the check happens in memory. Two processes that both believe they own an account would approve the same funds twice, and a writer paused by a long garbage collection can wake up after a new writer took over. `SOLUTION.md` tracks this record as AD-P1-04, with the protocol in section 4.1.

## Decision

Each account shard has one authoritative writer that holds a lease and a stable Kafka `transactional.id`, so a new writer fences the old one. The writer keeps available, reserved and unsettled amounts per account and asset, and commits every transition together with the consumed offsets in one Kafka transaction. Orders carry an idempotency key of account plus client order ID, kept until the order is terminal and for 24 h after.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Optimistic concurrency on a balance row in the database | Standard pattern, the database enforces the invariant | A database call per order and retries under contention | ADR-P1-0003 keeps the database off the order path |
| A distributed lock per account in Valkey | Familiar, no sharding protocol | A lock without fencing cannot stop a paused writer that wakes up | Unsafe under pauses and partitions |
| One global risk writer | Trivial ordering | One core caps throughput and one failure stops all trading | Fails REL-DP3 and stage 1 of the scaling plan |

## Trade-offs

A shard is unavailable for new orders while a new writer takes the lease and replays its partition. Orders for that shard fail fast and clients retry with the same client order ID, so the failover costs availability (REQ-P1-12A) and never correctness. PERF-DP5 is served by keeping the hot state in one process per shard.

## Consequences

### Positive

- Every balance change has one writer and one causing event ID, so a replay applies each input exactly once.
- A fill credits proceeds as unsettled until the ledger commits, so a ledger failure never creates spendable funds.

### Negative

- The settlement lag rule rejects exposure-increasing orders above 5 s of lag and halts new orders above 30 s, so a ledger outage stops trading.

### Risks

- A bug in the transitions could still let reservations drift from the ledger. Reconciliation at every ledger checkpoint (SC-03 in Problem 5) compares both and halts the affected shards on a diff.

## Verification

Double-spend, crash between reservation and commit, and partial-fill tests (review).

## Reopen when

A product needs one reservation across accounts in different shards, such as portfolio margin, or a reconciliation finds a diff between the risk engine and the ledger at a checkpoint.
