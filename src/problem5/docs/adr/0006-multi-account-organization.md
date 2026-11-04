# ADR-P5-0006: Multi-account organization with SCPs

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P5-2 |
| Principles | SEC-DP4, FSI-DP4, SEC-DP1 |
| Supersedes | none |

## Context

In a single account, one administrator role reaches the hot keys, the logs that would show their use and the backups that would undo the damage. SCPs do not affect users or roles in the management account (Organizations page, read 2026-11-04). Centralized root access lets the organization remove root user credentials from member accounts (IAM page, same day). Long-lived keys for workloads, CI and people outlive the sessions they were meant for.

## Decision

Separate accounts for production, wallet, log archive, backup, security tooling and non-production sit under SCPs that keep CloudTrail, GuardDuty and AWS Config on and stop accounts from leaving the organization. The management account runs no workloads, its root user has hardware MFA and no access keys, and member accounts have their root credentials removed. Workloads use EKS Pod Identity per service, CI uses OIDC, people use SSO with short sessions, and no IAM users exist.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| One account with IAM boundaries | Simplest to run | One compromised administrator role reaches keys, logs and backups | Fails TH-01, TH-09 and TH-11 |
| An account per service | The smallest blast radius | Cross-account access on the latency path to MSK and Aurora, and many more accounts to run | Costs latency and operations for little gain over six accounts |
| IAM users with access keys for CI and services | No federation to set up | Long-lived keys in pipelines and pods | Fails SEC-DP1 |

## Trade-offs

More accounts mean more cross-account wiring and more settings to keep consistent, which is operations work spent on structure instead of product (COST-DP4). The wallet path crosses an account boundary, which costs latency on withdrawals only, off the order path.

## Consequences

### Positive

- A compromise of the production account reaches neither the keys, the log archive nor the backup vault.
- People and workloads hold only short-lived credentials.

### Negative

- Account creation and SCP changes become a change process of their own.

### Risks

- An SCP mistake blocks a needed operation. SCP changes go through review and reach the non-production account first.

## Verification

Review: policy review with denial test cases per role, such as an attempt to stop CloudTrail from a member account.

## Reopen when

A workload needs access across accounts that the boundaries do not allow, or a new product line needs its own set of accounts.
