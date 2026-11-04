# ADR-P5-0014: Deferred controls and accepted risks with reopen triggers

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-2, REQ-P5-3, REQ-P5-5 |
| Principles | SEC-DP1, SEC-DP3, SEC-DP5, SEC-DP6, SEC-DP7, REL-DP1, REL-DP2, GEN-DP6, PERF-DP2 |
| Supersedes | none |

## Context

Some controls cost more at launch than they protect, and one of them cannot fit the order path until its latency is measured. A deferral without a trigger tends to become permanent, and an accepted risk without a stated reason cannot be challenged.

## Decision

SC-17 to SC-21 are deferred and SC-22 to SC-24 are accepted. Each one is recorded in the trade-off register of SOLUTION.md section 10.1 with the opposed principle, the forcing requirement, the consequence accepted and a measurable reopen trigger, and a fired trigger reopens the change at the next security review.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Build every control before launch | No deferred risk | A mesh hop on the order path before anyone measured it, and more work ahead of the launch gates | Breaks REQ-P1-8 and delays the controls that protect funds |
| Defer without triggers | Less paperwork | Nobody knows when to revisit a deferral | Deferrals turn permanent |

## Trade-offs

| Change | Type | Opposed principle | Reopen when |
|---|---|---|---|
| SC-17 mTLS through a service mesh | deferred | SEC-DP5 | A measured mesh overhead under 2 ms p99 on the order path, or a lateral-movement finding |
| SC-18 Macie and enforced data classification | deferred | SEC-DP5, SEC-DP6 | PII stored outside the KYC vendor |
| SC-19 Bug bounty and recurring game days | deferred | SEC-DP7, GEN-DP6 | Penetration test findings closed after launch |
| SC-20 Nitro Enclaves for the signer | deferred | SEC-DP6 | A penetration test bypasses the signer policy inside its account |
| SC-21 SOAR automation | deferred | SEC-DP7 | More than 20 actionable findings per week |
| SC-22 Cognito revocation gap on trading calls | accepted | SEC-DP1 | The regulator requires instant revocation of every session |
| SC-23 One active region | accepted | REL-DP1, PERF-DP2 | A region-loss RTO under 1 h becomes a requirement |
| SC-24 Public market data without authentication | accepted | SEC-DP3 | Scraping load above the rate-limit design |

## Consequences

### Positive

- Every open risk has a signal that brings it back.

### Negative

- The triggers need measurements, such as the mesh overhead and the weekly count of actionable findings, that someone has to produce.

### Risks

- A trigger that nobody watches. Each trigger maps to a metric or to an item of the security review.

## Verification

Review: each deferred and accepted row in SOLUTION.md section 10.1 names its opposed principle, forcing requirement, consequence and trigger.

## Reopen when

Any trigger in the register fires.
