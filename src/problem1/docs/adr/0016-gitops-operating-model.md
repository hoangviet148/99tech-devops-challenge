# ADR-P1-0016: IaC with GitOps and canaries, documented operating model

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-5, REQ-P1-7, REQ-P1-8 |
| Principles | OPS-DP1, OPS-DP3, OPS-DP4, OPS-DP5, OPS-DP6, REL-DP2, REL-DP5, GEN-DP2, GEN-DP6, FSI-DP1, FSI-DP2 |
| Supersedes | none |

## Context

Most outages start with a change, and an exchange cannot test a bad deploy on all users at once. A risk or matching shard has one writer, so a canary of a single-writer service cannot take a share of its traffic, and a matching rules change breaks replay unless the log records where it took effect. Failover paths that nobody exercises fail when they are needed. Regulators of financial services expect documented operations: who is on call, which runbook applies and how changes reach production. `SOLUTION.md` tracks this record as AD-P1-16, AD-P1-17 and AD-P1-19.

## Decision

AWS resources live in Terraform and workloads in Git, deployed by Argo CD, with Argo Rollouts canaries that roll back automatically on SLO burn, while matching and risk shards are released one shard at a time and matching rules change only at the offset of a rules-version command in the symbol partition. Load tests at production scale, an AZ game day, a restore drill and the DR exercise run before launch. Teams own bounded contexts with their own on-call rotation and runbooks.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Changes from the console | Fastest for one change | Drift, no review, no audit trail | Fails REL-DP5 and FSI-DP2 |
| CI pushes manifests to the cluster | Simple pipeline | CI holds write credentials for production, no drift correction | Wider blast radius of a CI compromise |
| Blue/green per service | Instant switch back | Twice the capacity during each deploy | Canaries limit the blast radius at lower cost |

## Trade-offs

A canary slows each rollout by its analysis window, and a production-scale test environment costs money while it runs. Both are accepted to keep changes small and reversible (OPS-DP4). A release of a single-writer service moves one shard at a time, slower than a canary, and a rules divergence shows in the standby's output comparison and in reconciliation rather than in SLO burn.

## Consequences

### Positive

- Every change is a reviewed commit, and Argo CD corrects drift.
- Failure paths are exercised before users depend on them (OPS-DP6, GEN-DP6).

### Negative

- Terraform and Argo CD become platform components with their own upgrades.

### Risks

- A canary share too small to see a regression lets it reach everyone. The canary analysis uses the same SLOs as the alerts, per request class.
- A rules change could make leader and standby diverge. The rules-version command switches both at the same offset, a mismatch pages, and the next shard waits until the comparison and reconciliation show no difference.

## Verification

GitOps and canary design in section 11.2 of `SOLUTION.md` (review), test plan in section 11.3 (review), runbook review (review), and the rules switch with a leader failover of section 4.2 (cloud run).

## Reopen when

A production change bypasses GitOps, or a regression passes the canary and breaches an SLO after full rollout.
