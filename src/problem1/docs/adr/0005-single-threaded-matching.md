# ADR-P1-0005: Single-threaded matching per symbol with a fenced hot standby

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-14A, REQ-P1-16A |
| Principles | PERF-DP5, REL-DP1, PERF-DP4, GEN-DP3 |
| Supersedes | none |

## Context

REQ-P1-14A requires deterministic matching per symbol, and REQ-P1-16A an order-to-match p99 under 50 ms. A leader cut off from the brokers can keep running, renew its lease and try to publish after a successor took over. Kafka transactions roll back what was written to Kafka, never the order book in memory, and a commit call can time out without telling whether it succeeded. A standby that diverged after the last periodic hash would promote with a wrong book. A release that changes a matching rule breaks replay unless the log records which rules produced which offsets. `SOLUTION.md` tracks this record as AD-P1-03 and the matching part of AD-P1-20, with the protocol in section 4.2.

## Decision

Each symbol shard has one single-threaded leader on pinned cores that holds a DynamoDB lease renewed only while its Kafka commits make progress, consumes committed input only, and commits outputs, input offsets and an incremental state hash in one Kafka transaction per batch, treating the book as speculative until the commit. A hot standby in another AZ compares its own outputs with the committed ones by event ID and promotes by taking the next token and fencing the stable `transactional.id`, resuming only when the outputs and the last batch hash match. Market buys run immediate-or-cancel at their protection price, self-trades and limit orders more than 10 % through the last trade price are handled by deterministic rules, a rules-version command in the log switches rules at one offset, and symbols move only under routing epochs.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Multi-threaded matching with locks per book | More throughput per symbol | Interleaving differs between runs, so a replay cannot reproduce the book | Breaks determinism (REQ-P1-14A) |
| Order book rows in a database | Durable without a log replay | Price-time priority needs row locks on hot price levels, so each symbol serializes on the database writer, with round trips on every match | Puts the ledger's database writer on the t1 to t2 path of REQ-P1-16A |
| Cold standby rebuilt from the last snapshot | No standby compute | Pod start-up, snapshot load from S3 and the rebuild of the book before the symbol trades again | Adds that time to every failover, against trading back within 1 min (REQ-P1-13A) |
| A full state hash every 10,000 offsets only | Cheaper than a hash per batch | At about 75 input commands per second the interval lasts more than 2 min, so a divergence after the last hash record can be promoted | Unsafe at the very failover the hash protects |
| A lease row in Aurora instead of DynamoDB | No second store for leases | Matching and risk availability tied to the ledger's writer and its failover | A ledger failover would stop matching and order entry with it |
| A self-run etcd or ZooKeeper for leases | Linearizable leases with watches | A consensus system to deploy, patch and monitor across 3 AZs | More to operate for the same fencing token that a conditional write on DynamoDB gives |

## Trade-offs

Fixed matching capacity sized for 3x works against PERF-DP3 and COST-DP2, a recorded trade-off in section 12 of `SOLUTION.md`. The DynamoDB lease adds a dependency, but a lost lease stops matching for one shard and never lets two leaders commit. Releasing one shard at a time slows delivery against OPS-DP4, accepted because a single-writer shard has no smaller canary unit. Under PERF-DP4 and GEN-DP3 the matching part of the AD-P1-20 benchmark measures the single-core cap before launch instead of assuming it.

## Consequences

### Positive

- Event IDs derive from input IDs that carry the recovery epoch, so reprocessing yields identical events and consumers deduplicate on them.
- A standby that diverges is detected at the next batch, and a promotion never resumes on an unverified book.

### Negative

- One symbol is capped by one core, which the stage 2 trigger of the scaling plan watches.
- Images carry every rules version still inside the 35-day horizon, and a release moves one shard at a time.

### Risks

- An ambiguous commit could duplicate output if handled wrongly. The engine stops, re-initializes its producer, reads back its committed offset and rebuilds, and the crash tests cover each commit boundary.
- A leader cut off from the brokers could hold its lease and stall the shard. Renewal stops 3 s after its last commit or broker round trip, and the partition test asserts the time to promotion.

## Verification

Process kills at each commit boundary, a Toxiproxy partition between the leader and the brokers with an assertion that the standby serves within 10 s, a lost commit response, a symbol move onto overlapping offsets with a stale-map risk writer holding an open transaction, a divergence injected between two hash records followed by a leader kill, a rules switch with a leader failover in the window, and self-trade and collar cases, each checking that no trade is lost or repeated (cloud run). The matching part of the AD-P1-20 benchmark of section 7.4 of `SOLUTION.md` (cloud run): a saturation run on one pinned `c8g.2xlarge` core and the same run unpinned, reporting the single-core matching throughput per symbol, pinned against unpinned t1 to t2 p99, and the pairs that the stage 0 pool carries.

## Reopen when

The matching part of the AD-P1-20 benchmark puts the busiest symbol above half of the single-core matching throughput, or a promotion in the partition test takes more than 10 s.
