# ADR-P5-0001: STRIDE over trust boundaries, ranked by impact on funds

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P5-3, REQ-P5-6 |
| Principles | FSI-DP3, SEC-DP3, SEC-DP7 |
| Supersedes | none |

## Context

The task asks for security inside the Problem 1 design instead of a section added at the end, and it asks for priorities: what comes first, what waits and what blocks shipping. The platform holds customer funds, so one flaw in the withdrawal path costs more than many flaws elsewhere. The method has to find threats in the flows this design actually has, and it has to rank them so the work gets an order.

## Decision

Six trust boundaries are marked on the Problem 1 design, STRIDE runs on every data flow that crosses one, and each threat gets an ID with at least one control or an accepted residual. Assets rank by impact with customer funds first, then ledger integrity, accounts, order flow, PII and availability, and the work follows that order. Each change is checked against the sixteen Problem 1 requirements before it enters the design.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| A control checklist from a security framework | Broad coverage that auditors recognize | Controls are not tied to the flows of this design, and custody threats such as approval reuse have no row | Finds generic gaps and misses the ones that move funds |
| Attack trees for customer funds only | Deep analysis of the largest loss | Misses threats across boundaries, such as a CI role that reaches production or a deleted backup | Too narrow for a platform with six boundaries |
| The Well-Architected security pillar questions alone | Aligned with AWS guidance | The questions describe practices, not threats, and carry no ranking by impact | No order of work comes out of it |

## Trade-offs

STRIDE on every crossing flow also produces threats of low impact, so the table grows longer than a checklist and costs review time. Ranking by funds first puts PII fifth, so Macie waits as SC-18 with a reopen trigger, which gives up part of SEC-DP6 for the order of work.

## Consequences

### Positive

- Every change names the threats it addresses, and every threat names its controls.
- The priority of each change follows from the asset it protects.

### Negative

- The threat table needs an update whenever a boundary or a data flow changes.

### Risks

- A flow missing from the diagram has no threats. A review of the threat table against the Problem 1 diagram and the external penetration test of SC-15 look for unmapped flows.

## Verification

Review: every SC row names at least one TH row, and every TH row names at least one SC row. Offline test: the traceability check of the submission fails on an undefined or unused threat ID.

## Reopen when

A new boundary appears, such as fiat rails, a third-party custodian or a FIX gateway, or an incident follows a path that the threat table does not contain.
