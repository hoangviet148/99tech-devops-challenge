# ADR-P1-0012: Backups, replay horizons and the regional recovery procedure

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-13A, REQ-P1-14A |
| Principles | REL-DP2, SEC-DP7 |
| Supersedes | none |

## Context

A ledger corruption found days later needs a restore point and a log long enough to replay every trade after it. Aurora and MSK replicate across regions asynchronously and independently, so the DR region holds two copies that can stop at different points. A promotion while old writers can still act would create two ledgers. `SOLUTION.md` tracks this record as AD-P1-18 and the procedure of section 6.1.

## Decision

The operational horizon is 35 days: Aurora point-in-time recovery, AWS Backup daily copies in a vault locked in compliance mode in the backup account, and Kafka with 7 days on brokers plus tiered storage to 35 days, with engine snapshots every 60 s kept 7 days in S3 with Object Lock. Monthly copies kept 12 months are archival and restore without replay. A region recovery resumes from the newest ledger checkpoint present in both replicated copies, and only after evidence that no old writer can act.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Aurora Global Database failover alone | One managed action | The log and the ledger stop at different points, and detaching a secondary does not fence old producers | No consistent boundary, a split ledger is possible |
| A 7-day horizon | Less backup and tiered storage | A corruption found after 7 days cannot replay to the present | Detection time is unknown before the first incident |
| Active-active regions | No restore during a region loss | Rejected in ADR-P1-0002 | Conflicts with one order sequence per symbol |

## Trade-offs

Backup and tiered storage cost money every month: 197.16 USD for tiered storage, 12.42 USD for the locked vault and 5.00 USD for snapshots in section 8.3 of `SOLUTION.md`. A region loss halts trading until a person decides, which REQ-P1-13A accepts.

## Consequences

### Positive

- Every operational restore point can replay to the present.
- A compromised production account cannot delete the copies in the backup account (SEC-DP7).

### Negative

- The region procedure needs people and evidence, so its duration is set by the first DR exercise.

### Risks

- Replicated offsets differ from source offsets, so a replay started by offset could skip or repeat trades. The runbook finds the replay start by the event IDs that the checkpoint records.

## Verification

Restore drill from a corrupted ledger before launch (cloud run), DR exercise (cloud run).

## Reopen when

A restore drill fails to reach a zero diff, or the regulator sets a region-loss RTO under 1 h.
