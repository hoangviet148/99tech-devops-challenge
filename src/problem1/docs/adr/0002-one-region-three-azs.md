# ADR-P1-0002: One region over three AZs with static capacity for an AZ loss

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-1, REQ-P1-2, REQ-P1-4, REQ-P1-12A, REQ-P1-13A |
| Principles | REL-DP1, REL-DP2, REL-DP3 |
| Supersedes | none |

## Context

REQ-P1-13A requires that an AZ loss loses no acknowledged data and that trading is back within 1 min. Capacity that Karpenter adds after the loss arrives after a lead time, so the surviving AZs must already carry the load. Risk writers and matching leaders are single writers per shard, so each needs a standby on its own pinned cores in another AZ. The wallet tier sits off the trading path, and withdrawals are asynchronous. Region loss is a separate decision, recorded in ADR-P1-0017. `SOLUTION.md` tracks this record as AD-P1-01 and AD-P1-10.

## Decision

Every trading tier runs in ap-southeast-1 across 3 AZs, and any two AZs carry 1.5x the normal peak under a 70 % CPU ceiling without new capacity, so the 9 stateless nodes run at about 30 % at normal peak, and the 6 pinned nodes, 2 per AZ, hold a leader and a hot standby of each of the 4 risk shards and 4 matching shards in different AZs and still host every leader after the loss of any one AZ. The wallet tier runs 2 hosts in 2 AZs, each running the signer and the watchers, so withdrawals continue on one host while a replacement starts. A region loss is covered by the warm standby of ADR-P1-0017.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Two AZs | One AZ fewer of static capacity | MSK with `min.insync.replicas=2` and `acks=all` stops accepting writes when one of two AZs is gone | Breaks REQ-P1-13A on the first AZ loss |
| Three AZs sized for normal peak, Karpenter adds capacity after a loss | Static capacity only for normal peak, the rest bought when needed | The lead time of new nodes becomes an outage window during the AZ loss | Trading back within 1 min would depend on node launch time |
| A third wallet host in the third AZ | Withdrawals keep two hosts through an AZ loss | One more host and one more endpoint AZ, paid around the clock | Withdrawals are asynchronous, so one host while a replacement starts is enough |

## Trade-offs

Static capacity works against COST-DP2 and SUS-DP3: about 30 % normal CPU load on the stateless pool and a standby for every risk writer and matching leader are paid around the clock, a recorded trade-off in section 12 of `SOLUTION.md`. The wallet tier in 2 AZs leaves withdrawals on one host during an AZ loss, recorded in the same register.

## Consequences

### Positive

- An AZ loss needs no new instance and no person.
- Each stateful tier has a replica in another AZ: MSK leaders, Aurora readers, the Valkey replica, the matching standby and the risk standby.

### Negative

- The stateless pool runs near 30 % average CPU, below what a consumption model would reach.
- During an AZ loss one wallet host carries every withdrawal until a replacement starts.

### Risks

- A burst above 1.5x during an AZ loss exceeds static capacity. Rate limits and the shedding order of ADR-P1-0011 bound it until Karpenter adds nodes.

## Verification

AZ game day with the Aurora writer in the failed AZ (cloud run). It passes when orders from every account are accepted again within 1 min, and it records the Aurora failover time, the settlement catch-up time and the peak settlement lag.

## Reopen when

Measured Karpenter lead time drops under 60 s, or an AZ game day takes more than 1 min to accept orders from every account again.
