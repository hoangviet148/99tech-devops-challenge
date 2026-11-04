# ADR-P1-0015: Scaling stages with measured triggers

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-3, REQ-P1-11 |
| Principles | GEN-DP1, GEN-DP4, GEN-DP5 |
| Supersedes | none |

## Context

REQ-P1-11 asks for a plan once the product outgrows the current setup. Reads and stateless work scale out without coordination, but writes scale only by adding shards, each with one writer, and accounts and symbols move between shards only through the handoff and routing-epoch protocols of sections 4.1 and 4.2 of `SOLUTION.md`. MSK holds the largest allocation of the order path, two commits of 15 ms, and t1 to t2 holds three. Building the 100x design at 500 rps would add cells, a new sequencer and cross-shard settlement before any measurement justifies them. `SOLUTION.md` tracks this record as AD-P1-12, with the stages in section 10.

## Decision

Scaling moves through stages, each opened by a measured trigger set below the value it protects. Stage 1 at about 10x opens on gateway CPU above 60 % sustained, a transactional commit p99 above 12 ms for risk writers or for matching leaders, an order-to-match p99 above 40 ms or Aurora writer CPU above 60 %, and adds a larger broker type or three more brokers with partition reassignment, broker storage for the stage 1 volume, more account shards through the handoff protocol and KEDA scaling capped at the partition counts. Stage 2 at about 100x opens on an order-to-match p99 above 40 ms after the stage 1 MSK change, or one symbol above half of the single-core matching throughput measured in the benchmark of section 7.4.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Build the stage 2 design now | No migration later | Cells, Aeron Cluster and cross-shard settlement for 500 rps | Complexity and cost without a measured need |
| Scale only vertically | Simple | One writer and one core per symbol cap growth | A ceiling with no plan past it |
| Autoscale matching shards on CPU | Elastic | Moving a symbol pauses, drains, snapshots and resumes it | Matching moves only through the routing-epoch protocol, never automatically |

## Trade-offs

Waiting for measured triggers, as GEN-DP1 and GEN-DP5 ask, means each stage starts under load, so every trigger sits below the value it protects: a commit p99 of 12 ms for each producer type against the 15 ms budget, an order-to-match p99 of 40 ms against the 50 ms of REQ-P1-16A, and 60 % gateway CPU against the 70 % ceiling of the stateless pool. GEN-DP4 is served by keeping the shard boundaries and move protocols that stage 2 needs from the start.

## Consequences

### Positive

- Read and write scaling are separate, so a read surge never forces a write migration.
- The MSK hop has its own stage 1 action, chosen by broker metrics rather than by the commit p99 alone.
- The ledger keeps one settlement writer until a tested cross-shard protocol exists.

### Negative

- Stage 2 needs design work that has not started: pending and final postings with durable transfer IDs.
- At about 10 MB/s, 7 days on brokers need about 6,000 GB per broker, or a shorter local retention with tiered storage.

### Risks

- Growth faster than one stage per quarter would compress the migration. The trigger metrics sit on dashboards with alerts at the trigger values.

## Verification

Trigger metrics on dashboards with alerts at the trigger values (cloud run).

## Reopen when

A trigger fires twice within one quarter, or the matching part of the section 7.4 benchmark already puts the busiest symbol above half of the single-core matching throughput at the stage 0 load.
