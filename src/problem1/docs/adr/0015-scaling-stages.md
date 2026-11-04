# ADR-P1-0015: Scaling stages with measured triggers

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-3, REQ-P1-11 |
| Principles | GEN-DP1, GEN-DP4, GEN-DP5 |
| Supersedes | none |

## Context

REQ-P1-11 asks for a plan once the product outgrows the current setup. Reads and stateless work scale out without coordination, but writes scale only by adding shards, each with one writer. Building the 100x design at 500 rps would add cells, a new sequencer and cross-shard settlement before any measurement justifies them. `SOLUTION.md` tracks this record as AD-P1-12, with the stages in section 10.

## Decision

Scaling moves through stages, each opened by a measured trigger. Stage 1 at about 10x opens on gateway CPU above 60 % sustained, MSK produce p99 above 30 ms or Aurora writer CPU above 60 %, and stage 2 at about 100x on an order path p99 above budget after stage 1 or one symbol above the measured single-core matching throughput.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Build the stage 2 design now | No migration later | Cells, Aeron Cluster and cross-shard settlement for 500 rps | Complexity and cost without a measured need |
| Scale only vertically | Simple | One writer and one core per symbol cap growth | A ceiling with no plan past it |
| Autoscale matching shards on CPU | Elastic | Moving a symbol pauses, drains, snapshots and resumes it | Matching moves only through the migration protocol, never automatically |

## Trade-offs

No principle is opposed. Waiting for triggers means each stage starts under load, so the triggers sit below the budgets they protect: 60 % CPU, and 30 ms produce p99 against a 100 ms end-to-end requirement.

## Consequences

### Positive

- Read and write scaling are separate, so a read surge never forces a write migration.
- The ledger keeps one settlement writer until a tested cross-shard protocol exists.

### Negative

- Stage 2 needs design work that has not started: pending and final postings with durable transfer IDs.

### Risks

- Growth faster than one stage per quarter would compress the migration. The trigger metrics sit on dashboards with alerts at the trigger values.

## Verification

Trigger metrics on dashboards (review).

## Reopen when

A trigger fires twice within one quarter, or the AD-P1-20 benchmark shows the busiest symbol above half of the single-core matching throughput.
