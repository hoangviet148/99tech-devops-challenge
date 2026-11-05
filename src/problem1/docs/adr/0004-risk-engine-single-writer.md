# ADR-P1-0004: Risk engine with one writer per account shard

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-14A, REQ-P1-2 |
| Principles | REL-DP1, PERF-DP5 |
| Supersedes | none |

## Context

Orders, fills, cancels, deposits and withdrawals all change the same balances, and REQ-P1-14A forbids a spendable balance below zero. ADR-P1-0003 keeps the database off the order path, so the check happens in memory. Two processes that both believe they own an account would approve the same funds twice, and a writer paused by a long garbage collection can wake up after a new writer took over. Kafka transactions roll back the log, never the writer's memory, and a commit call can time out without a result. A writer's open transaction also holds the last stable offset of every shared symbol partition it wrote to, so a dead writer stalls matching for other accounts too. `SOLUTION.md` tracks this record as AD-P1-04, with the protocol in section 4.1.

## Decision

Each account shard has one writer and a hot standby in another AZ that tails the shard partition, and every takeover takes the DynamoDB lease with the next fencing token, calls `initTransactions` on the shard's stable `transactional.id`, reads the shard partition to its `read_committed` end and only then accepts orders, while a fenced writer stops without acknowledging its in-flight orders. The writer keeps available, reserved and unsettled amounts per account and asset as speculative state until the transaction that carries them commits, group-commits the orders that arrive during an in-flight commit, and answers an ambiguous commit with "outcome unknown, retry with the same client order ID" before it rebuilds from its snapshot and shard partition. Input IDs carry a recovery epoch and a sequence that never goes back, across aborts and takeovers too, risk producers set a 10 s transaction timeout so that an open transaction of a dead writer ends within 20 s even without a successor, and orders carry an idempotency key of account plus client order ID, kept until the order is terminal and for 24 h after.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Optimistic concurrency on a balance row in the database | Standard pattern, the database enforces the invariant | A database call per order and retries under contention | ADR-P1-0003 keeps the database off the order path |
| A distributed lock per account in Valkey | Familiar, no sharding protocol | A lock without fencing cannot stop a paused writer that wakes up | Unsafe under pauses and partitions |
| One global risk writer | Trivial ordering | One core caps throughput and one failure stops all trading | Fails REL-DP3 and stage 1 of the scaling plan |
| A cold replacement writer rebuilt from the latest snapshot | No standby cores | Pod start-up, snapshot load and replay before the shard takes orders again | Adds that time to every failover, against trading back within 1 min |
| Separate input partitions per risk shard and matching shard | A dead writer stalls only its own shard | The matching leader must record a merge order across partitions for every replay | More to get right for the determinism of REQ-P1-14A than a stall bounded at 10 s through a successor and 20 s without one |

## Trade-offs

A shard takes no new orders for up to 10 s while its standby takes over, and the open transaction of a dead writer stops matching on the symbol partitions it touched for every account until the successor fences it, within the same 10 s, or for up to 20 s when the transaction timeout and the broker's abort sweep end it without a successor. Both cost availability (REQ-P1-12A) and never correctness. The hot standbys double the pinned cores of the risk engine, against COST-DP2 and SUS-DP3, and PERF-DP5 is served by keeping the hot state in one process per shard.

## Consequences

### Positive

- Every balance change has one writer and one causing event ID, so a replay applies each input exactly once.
- A commit by an old writer either precedes the fence and is part of the successor's state, or follows it and fails as fenced.
- A fill credits proceeds as unsettled until the ledger commits, so a ledger failure never creates spendable funds.

### Negative

- The settlement lag rule rejects exposure-increasing orders above 5 s of lag and halts new orders above 90 s until lag is back under 5 s, so a long ledger outage stops trading.
- An account changes shards only through a handoff record, and a command sent to the old shard during a move fails fast.

### Risks

- A bug in the transitions could still let reservations drift from the ledger. Reconciliation at every ledger checkpoint (Problem 5 SC-03) compares both and halts the affected shards on a diff.
- A wrong answer to an ambiguous commit would duplicate an order or leave a reservation without one. The writer never rejects a pending order after a timeout, and the lost-commit tests cover order and fill transactions.

## Verification

Against MSK (cloud run): double-spend, a crash between reservation and commit, a writer paused past its lease once between reservation and commit and once before `beginTransaction`, an abortable error after a reservation that checks that the resent orders take new sequence numbers, a lost commit response on an order transaction and on a fill transaction with a client retry after each, a writer killed between produce and commit while the other shards' t1 to t2 is measured, a market buy that sweeps past its protection price, and an account move with a resting partly filled order, a pending withdrawal and a retried client order ID, with a crash at each step.

## Reopen when

A product needs one reservation across accounts in different shards, such as portfolio margin, a reconciliation finds a diff between the risk engine and the ledger at a checkpoint, or the crash test measures a stall on a shared symbol partition above 10 s through the takeover path or above 20 s through the timeout path.
