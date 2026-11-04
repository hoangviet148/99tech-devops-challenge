# ADR-P1-0006: Amazon MSK as sequencer and event log, final after a benchmark

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-8, REQ-P1-16A |
| Principles | OPS-DP8, PERF-DP1, PERF-DP4, GEN-DP3 |
| Supersedes | none |

## Context

The risk writer and the matching engine need a replicated, ordered log with transactions that commit outputs and consumed offsets together, replay over the 35-day horizon of ADR-P1-0012, and a produce p99 inside the 30 ms allocation. Kinesis Data Streams documents a typical average propagation of 70 ms with dedicated-throughput consumers, against a 20 ms order-to-match objective, but an average says nothing reliable about p99. `SOLUTION.md` tracks this record as AD-P1-06 and AD-P1-20.

## Decision

Amazon MSK provisioned runs three brokers, one per AZ, with replication factor 3, `min.insync.replicas=2`, `acks=all`, a stable `transactional.id` per shard, 7 days of broker retention and tiered storage to 35 days on `cleanup.policy=delete` topics. The choice stays provisional until a benchmark harness measures MSK and Kinesis at the t1 to t2 boundary under the stage 0 load.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Kinesis Data Streams | Fully managed shards, no broker sizing | No transaction across writes and offsets, a documented 70 ms average propagation | Provisionally rejected until the benchmark measures p99 |
| SQS FIFO | Managed ordering per group | No replay of consumed messages | Recovery and standbys need replay |
| Aeron Cluster or an in-memory Raft log | Microsecond sequencing | A consensus system the team operates | The stage 2 path when MSK latency limits growth |
| MSK Serverless or Express brokers | Less capacity planning | Latency and transaction behaviour unmeasured for this path | Kept as the reopen trigger |

## Trade-offs

Provisioned brokers work against COST-DP2: 558.45 USD per month for the brokers whatever the load (section 8.3 of `SOLUTION.md`). OPS-DP8 is served because AWS runs the brokers, patching and replication.

## Consequences

### Positive

- Exactly-once processing between the risk writer, matching and settlement through transactions and deduplication on event IDs.
- One log feeds standbys, settlement, market data, analytics and the DR region through MSK Replicator.

### Negative

- Broker size and partition counts are capacity decisions the team revisits at each scaling stage.

### Risks

- Produce p99 above 30 ms breaks the order path budget. The load test reports it per hop, and the stage 1 trigger fires on it.

## Verification

Produce p99 in the load test (cloud run), benchmark report for MSK and Kinesis at the t1 to t2 boundary (cloud run).

## Reopen when

The benchmark shows a serverless or Express option within the 30 ms produce allocation, or Kinesis under 20 ms p99 for t1 to t2.
