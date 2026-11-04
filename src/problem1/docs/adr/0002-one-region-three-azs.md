# ADR-P1-0002: One region over three AZs with static capacity for an AZ loss

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-1, REQ-P1-2, REQ-P1-4, REQ-P1-12A, REQ-P1-13A |
| Principles | REL-DP1, REL-DP2, REL-DP3 |
| Supersedes | none |

## Context

REQ-P1-13A requires that an AZ loss loses no acknowledged data and that trading is back within 1 min. Capacity that Karpenter adds after the loss arrives after a lead time, so the surviving AZs must already carry the load. A second active region would survive a region loss, but one order sequence per symbol cannot be written in two regions without consensus across them on the order path. `SOLUTION.md` tracks this record as AD-P1-01 and AD-P1-10.

## Decision

Every tier runs in ap-southeast-1 across 3 AZs, and any two AZs carry 1.5x the normal peak without new capacity, so each AZ holds 0.75x and normal CPU load sits at about 44 %. Matching engines stay sized for 3x bursts. A region loss halts trading until a person runs the recovery procedure of ADR-P1-0012.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Two AZs | One AZ fewer of static capacity | MSK with `min.insync.replicas=2` and `acks=all` stops accepting writes when one of two AZs is gone | Breaks REQ-P1-13A on the first AZ loss |
| Three AZs sized for normal peak, Karpenter adds capacity after a loss | Static capacity only for normal peak, the rest bought when needed | The lead time of new nodes becomes an outage window during the AZ loss | Trading back within 1 min would depend on node launch time |
| Active-active in two regions | Survives a region loss | Cross-region consensus on the order path, two sequences per symbol otherwise | Conflicts with REQ-P1-8 and REQ-P1-14A |

## Trade-offs

Static capacity works against COST-DP2 and SUS-DP3: about 44 % normal CPU load is paid around the clock, a recorded trade-off in section 13 of `SOLUTION.md`. One active region works against PERF-DP2, and a region loss halts trading by design.

## Consequences

### Positive

- An AZ loss needs no new instance and no person.
- Each stateful tier has a replica in another AZ: MSK leaders, Aurora readers, the Valkey replica and the matching standby.

### Negative

- The stateless pools run near 40 % average CPU, below what a consumption model would reach.

### Risks

- A burst above 2.25x during an AZ loss exceeds static capacity. Rate limits and load shedding at the gateway (ADR-P1-0011) bound it until Karpenter adds nodes.

## Verification

AZ game day (review), DR exercise (cloud run).

## Reopen when

Measured Karpenter lead time drops under 60 s, or the regulator or the business sets a region-loss RTO under 1 h.
