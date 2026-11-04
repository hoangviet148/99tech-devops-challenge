# ADR-P1-0005: Single-threaded matching per symbol with a fenced hot standby

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-14A, REQ-P1-16A |
| Principles | PERF-DP5, REL-DP1 |
| Supersedes | none |

## Context

REQ-P1-14A requires deterministic matching per symbol, and REQ-P1-16A an order-to-match p99 under 20 ms. A leader cut off from the brokers can keep running and try to publish after a successor took over. Kafka transactions roll back what was written to Kafka, never the order book in memory, and a commit call can time out without telling whether it succeeded. `SOLUTION.md` tracks this record as AD-P1-03, with the protocol in section 4.2.

## Decision

Each symbol shard has one single-threaded leader on pinned cores. It holds a DynamoDB lease with a fencing token that grows with every new leader, consumes committed input only, and commits outputs with input offsets in one Kafka transaction per batch, treating the book as speculative until the commit. A hot standby in another AZ applies the same input, checks a state hash every 10,000 offsets, and promotes by taking the next token and fencing the stable `transactional.id`.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Multi-threaded matching with locks per book | More throughput per symbol | Interleaving differs between runs, so a replay cannot reproduce the book | Breaks determinism (REQ-P1-14A) |
| Order book rows in a database | Durable without a log replay | Milliseconds and row locks per operation | Cannot hold 20 ms p99 under 3x bursts (REQ-P1-16A) |
| Cold standby rebuilt from the last snapshot | No standby compute | Up to 60 s of snapshot age to replay before the symbol trades again | Puts trading back within 1 min (REQ-P1-13A) at risk |

## Trade-offs

Fixed matching capacity sized for 3x works against PERF-DP3 and COST-DP2, a recorded trade-off in section 13 of `SOLUTION.md`. The DynamoDB lease adds a dependency, but a lost lease stops matching for one shard and never lets two leaders commit.

## Consequences

### Positive

- Event IDs derive from input IDs, so reprocessing yields identical events and consumers deduplicate on them.
- A standby that diverges is detected at the next hash record instead of at promotion.

### Negative

- One symbol is capped by one core, which the stage 2 trigger of the scaling plan watches.

### Risks

- An ambiguous commit could duplicate output if handled wrongly. The engine stops, re-initializes its producer, reads back its committed offset and rebuilds, and the crash tests cover each commit boundary.

## Verification

Process kills before producing, after producing and after committing, broker partitions through Toxiproxy, a lost commit response, and a symbol migration onto overlapping offsets, each checking that no trade is lost or repeated (cloud run).

## Reopen when

The AD-P1-20 benchmark shows a managed option under 20 ms p99 for t1 to t2, or one symbol exceeds the measured single-core matching throughput.
