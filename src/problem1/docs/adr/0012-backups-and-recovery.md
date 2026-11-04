# ADR-P1-0012: Backups, replay horizons and ordered replay

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-13A, REQ-P1-14A |
| Principles | REL-DP2, SEC-DP7 |
| Supersedes | none |

## Context

A ledger corruption found days later needs a restore point and a log long enough to replay every ledger input after it: trades, deposit confirmations and withdrawal end states. Kafka keeps no order across partitions, so a replay that settles a sale before the purchase that funded it fails the CHECK and stops. An input ID issued again after a recovery would collide with a trade already settled under it. Aurora stores every cluster snapshot copy in full, and copies kept only in the production account can be deleted by whoever compromises that account. `SOLUTION.md` tracks this record as AD-P1-18, and AD-P1-10 links it for the replay and the recovery epoch.

## Decision

The operational horizon is 35 days: Aurora point-in-time recovery, Kafka with 7 days on brokers plus tiered storage to 35 days, and 35 daily and 12 monthly full copies of the ledger in a vault in the backup account whose compliance-mode lock is Problem 5 SC-16, with production-side recovery points expiring within 35 days and engine snapshots every 60 s kept 7 days in S3 with Object Lock. A restore replays every ledger input after its checkpoint in the source commit order, taken from the original cluster's outbox table or from the ledger commit sequence, and past that point pauses only the partition whose next record fails a CHECK. Input IDs carry a recovery epoch that a region promotion raises above every epoch in the replicated copies, so no ID repeats.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| A 7-day horizon | Less backup and tiered storage | A corruption found after 7 days cannot replay to the present | Detection time is unknown before the first incident |
| Replay each partition to its end in offset order | Simple, no ordering data | Kafka keeps no order across partitions, so a dependent trade on another symbol fails the CHECK and the replay stops | The restore would never reach the present |
| Resume each shard's sequence above the highest one found, with no epoch | No new ID field | Misses IDs that reached clients or other stores but neither replicated copy | A reissued ID can collide with a settled trade |
| EBS volume per engine with snapshot lock | Regional snapshots that restore in any AZ, with a compliance-mode lock | A volume per engine, a snapshot call every 60 s, a volume created and attached before any read and slower until its blocks arrive, and a lock call after each snapshot, since a snapshot cannot be locked during creation | A standby reads the S3 state record with one GET, and the bucket's default retention locks every object as it is written |
| Snapshots kept only in the production account | No backup account and no cross-account copy | Whoever compromises the production account can delete every copy | Fails SEC-DP7 against a compromised production account |

## Trade-offs

Backup and tiered storage cost money every month, against COST-DP2: the tiered storage, vault and engine snapshot lines of section 8.3 of `SOLUTION.md`, 197.16, 216.20 and 5.00 USD per month, where each vault copy is a full copy of the ledger. The horizon serves REL-DP2, because every restore drill can replay to the present.

## Consequences

### Positive

- Every operational restore point can replay to the present: retention keeps every input after it, and the ordered replay settles them in a valid order.
- A compromised production account cannot delete the copies in the backup account (SEC-DP7).
- No ID issued after a promotion equals one issued before it.

### Negative

- The vault grows with the ledger, 47 full copies at a time.
- A replay needs the commit sequence on every outbox row and the consumed positions in every checkpoint.

### Risks

- Replicated offsets differ from source offsets, so a replay started by offset could skip or repeat trades. The runbook finds the replay start by the event IDs that the checkpoint records.
- A CHECK failure left after every partition reaches the present means the log cannot be settled as recorded. It is an integrity error that keeps the halt until people resolve it.

## Verification

Restore drill from a corrupted ledger before launch, with dependent trades of one account on two symbols, reaching a zero diff (cloud run).

## Reopen when

A restore drill fails to reach a zero diff, or a corruption is found more than 35 days after it happened.
