# ADR-P5-0010: Detection, immutable audit and locked backups

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P5-2, REQ-P1-13A |
| Principles | SEC-DP2, SEC-DP4, SEC-DP7, FSI-DP4, REL-DP2 |
| Supersedes | none |

## Context

An attacker with administrator access first removes what would expose or undo the attack: trails, detectors and backups. No SOC exists at launch (assumed in FN-07). The pages read on 2026-11-04 say that GuardDuty Runtime Monitoring covers EKS. A backup vault locked in compliance mode cannot be changed or deleted by any user or by AWS once its grace time ends, and its backups stay until their retention ends. A lock in governance mode can be removed by users with enough IAM permissions.

## Decision

An organization CloudTrail writes to the log archive account with S3 Object Lock, next to an immutable audit log of balance changes and admin actions. GuardDuty with Runtime Monitoring for EKS, Security Hub CSPM, AWS Config and VPC Flow Logs report to the security tooling account, and findings go to on-call. Backups sit in an AWS Backup vault in the backup account, locked in compliance mode.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Logs and backups in the production account | No cross-account setup | The attacker who owns production deletes them | Fails TH-09 and TH-11 |
| Vault lock in governance mode | Reversible if the retention is wrong | Users with enough IAM permissions can remove the lock | Removable by the very principal it guards against |
| A self-managed log and detection stack on EKS | Full control of the rules | Another system to run, inside the account it watches | OPS-DP8, and it breaks the account separation of SC-06 |

## Trade-offs

Compliance mode cannot be reversed after the grace time, so a wrong retention setting stays, which gives up the reversibility of OPS-DP4. Logs and findings cost money per GB and per event (REQ-P1-4). Response stays manual until SC-21.

## Consequences

### Positive

- Deleting backups or trails needs access that the production account does not have.
- Every balance change and admin action has a record its author cannot edit.

### Negative

- Without a SOC, findings add load to on-call.

### Risks

- Alert fatigue hides a real finding. The trigger of SC-21, more than 20 actionable findings per week, brings automation forward.

## Verification

Review: event coverage against the threat table. Cloud run: test events delivered to the locked log archive, a denied delete of a locked object from a workload account, a GuardDuty sample finding that reaches the on-call destination, and a backup deletion attempt from the production account.

## Reopen when

Actionable findings exceed 20 per week, or a SOC takes over the routing.
