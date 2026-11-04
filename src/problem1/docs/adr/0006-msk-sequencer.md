# ADR-P1-0006: Amazon MSK as sequencer and event log, final after a benchmark

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-8, REQ-P1-16A |
| Principles | OPS-DP8, PERF-DP1, PERF-DP4, GEN-DP3 |
| Supersedes | none |

## Context

The risk writer and the matching engine need a replicated, ordered log with transactions that commit outputs on several partitions together with the consumed offsets, a stable `transactional.id` that fences an old producer, and replay over the 35-day horizon of ADR-P1-0012. Every transactional produce and commit has a p99 budget of 15 ms (section 7.1 of `SOLUTION.md`), because t1 to t2 can hold three commits inside the 50 ms of REQ-P1-16A. Kinesis Data Streams processes each record of a `PutRecords` call on its own, its client library KCL keeps consumer positions in a DynamoDB lease table outside the stream, and the service documents a typical average propagation of 70 ms with dedicated-throughput consumers. `SOLUTION.md` tracks this record as AD-P1-06 and AD-P1-20.

## Decision

Amazon MSK provisioned runs three `kafka.m7g.large` brokers, one per AZ, with replication factor 3, `min.insync.replicas=2`, `acks=all`, a stable `transactional.id` per shard, 7 days of broker retention and tiered storage to 35 days on `cleanup.policy=delete` topics. Kinesis Data Streams is rejected because it has no transaction across shards and consumer positions and no producer fencing. The sequencer part of the benchmark of section 7.4 measures provisioned brokers against MSK Express brokers, and against MSK Serverless once an AWS page states that it supports transactions, and the choice is final when the commit p99 of risk-writer transactions and of matching batch transactions, each measured on its own, stays within 15 ms and t1 to t2 under 50 ms.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Kinesis Data Streams | Fully managed shards, no broker sizing | `PutRecords` processes each record on its own, KCL keeps positions in a DynamoDB table, nothing fences an old producer, and a documented 70 ms average propagation | Sections 4.1 and 4.2 need one transaction across partitions and consumer positions and a fenced `transactional.id`, so no latency result could make it usable without a new protocol |
| SQS FIFO | Managed ordering per group | No replay of consumed messages | Recovery and standbys need replay |
| Aeron Cluster or an in-memory Raft log | Microsecond sequencing | A consensus system the team operates | The stage 2 path when MSK latency limits growth |
| MSK Express brokers or MSK Serverless | Less capacity planning, and the Express configuration pages list the transaction settings | Commit latency unmeasured on this path, and the Serverless pages state nothing about transactions | Measured in the sequencer part of the section 7.4 benchmark and adopted only within the 15 ms commit budget |

## Trade-offs

Provisioned brokers work against COST-DP2: 558.45 USD per month for the brokers whatever the load (section 8.3 of `SOLUTION.md`). Rejecting Kinesis works against PERF-DP3, since brokers need sizing and patching where a serverless stream would not. OPS-DP8 is served because AWS runs the brokers, patching and replication.

## Consequences

### Positive

- Exactly-once processing between the risk writer, matching and settlement through transactions and deduplication on event IDs.
- One log feeds standbys, settlement, market data, analytics and the DR region through MSK Replicator.

### Negative

- Broker type, count and storage change at stage 1 of the scaling plan, chosen by broker CPU, network throughput against the instance baseline and request queue time (section 10 of `SOLUTION.md`).
- Rolling patching moves leadership one broker at a time, and each window burns part of the order-to-match objective.

### Risks

- A commit p99 above the 15 ms budget breaks the MSK hop of section 7.1 and the t1 to t2 allocation of section 7.3. The load test reports it per hop and per producer type, the stage 1 trigger fires at 12 ms for either type, and the stage 1 MSK change adds broker capacity or storage.

## Verification

Commit p99 of risk-writer and of matching transactions, each on its own, and t1 to t2 p99 in the load test (cloud run), and the sequencer part of the section 7.4 benchmark with 4 risk writers producing to one symbol partition at 500 rps and on the 1500 rps plateau (cloud run).

## Reopen when

The sequencer part of the section 7.4 benchmark puts Express brokers or MSK Serverless within the 15 ms commit budget with t1 to t2 under 50 ms, the commit p99 of either producer type stays above 12 ms after the stage 1 MSK change, or AWS adds transactions across shards and producer fencing to Kinesis Data Streams.
