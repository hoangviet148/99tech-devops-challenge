# ADR-P1-0007: Aurora PostgreSQL ledger with outbox and checkpoints

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-14A, REQ-P1-13A, REQ-P1-2, REQ-P1-4 |
| Principles | REL-DP1, SEC-DP2, OPS-DP8, COST-DP4, SUS-DP5 |
| Supersedes | none |

## Context

The ledger is the record of truth for balances: postings must balance, no trade may settle twice, and no balance may go negative. Settlement consumes fills from Kafka and must publish balance events back without a dual write that could commit in one system and fail in the other. Reconciliation and region recovery need a consistent point where the ledger and the log agree. `SOLUTION.md` tracks this record as AD-P1-05 and the managed-service part of AD-P1-08, with the protocol in section 4.3.

## Decision

Each trade settles in one Aurora PostgreSQL transaction that holds a deduplication row keyed by trade ID, balanced postings checked in the posting function and by a deferred constraint trigger, balance updates under `CHECK (available >= 0)`, and an outbox row. An outbox relay publishes balance events at least once, and every 60 s a checkpoint row and the same record on the `ledger-checkpoints` topic mark what the ledger has consumed.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| DynamoDB transactions | Serverless, no instance sizing | At most 100 items per transaction, reconciliation queries need exports | Harder invariant checks and reconciliation for REQ-P1-14A |
| Self-managed PostgreSQL on EC2 | Full control, no Aurora premium | Replication, failover and backups to build and test | More operations for the same guarantees (COST-DP4) |
| Event-sourced balances in Kafka only | One system | No constraint enforcement at the store, every query needs a materialized view | The invariants would live only in application code |

## Trade-offs

One Aurora writer settles every trade, which works against REL-DP3 at scale: settlement throughput is capped by that writer until a tested cross-shard protocol exists (stage 2 of the scaling plan). A cross-shard design with pending and final postings is deliberately left out until a trigger fires.

## Consequences

### Positive

- The database rejects an unbalanced posting, a duplicate trade and a negative balance, whatever the application does.
- Checkpoints give reconciliation and region recovery the same boundary (SEC-DP2).

### Negative

- Consumers of balance events must deduplicate by event ID, because the relay delivers at least once.

### Risks

- Lock contention on hot accounts could slow settlement. Rows are locked in account ID order under `READ COMMITTED`, and settlement p99 under 1 s is an SLO with its own alert.

## Verification

Property-based tests generate random trade sequences and check the invariants after each one (review).

## Reopen when

Aurora writer CPU stays above 60 % after the stage 1 larger writer, or settlement p99 exceeds 1 s.
