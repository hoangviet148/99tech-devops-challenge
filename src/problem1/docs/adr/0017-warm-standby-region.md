# ADR-P1-0017: Warm standby region with a committed RPO and RTO

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-4, REQ-P1-13A, REQ-P1-14A |
| Principles | REL-DP2 |
| Supersedes | none |

## Context

REQ-P1-13A commits a region loss to an RPO of 1 min of acknowledged orders and trades and to trading back within 1 h of the start of the outage. Aurora Global Database and MSK Replicator copy asynchronously and independently, so the DR region holds two copies that stop at different points. While ap-southeast-1 is down, nothing in it can be stopped or read back, so every fence must be set from outside it. A cross-region lease checked on the trading path would add an inter-region round trip to every order, against REQ-P1-8 and REQ-P1-16A. Capacity started after the loss would put instance launches and warm-up inside the 1 h, and re-enrolling every user would not fit it either. `SOLUTION.md` tracks this record as AD-P1-10, with the procedure in section 6.1.

## Decision

A warm standby in `<DR_REGION>` runs every service over three AZs at reduced size with quiescent writers, fed by MSK Replicator and an Aurora Global Database secondary, with Cognito multi-Region replication, KMS replicas and a quiescent DR signer, and CloudFront serves GET, HEAD and OPTIONS through an origin group whose secondary is the DR origin. A person declares the loss and promotes after fencing the client path through CloudFront, withdrawals through a signer lease held in `<DR_REGION>` whose table policy then denies the primary signer, and the data copies by stopping MSK Replicator and failing Aurora over from the DR region, while old-region trading writers need no fence, are stopped when ap-southeast-1 still answers, and leave a divergent tail that is reconciled when the region returns. Each risk writer writes a loss witness every second to a control table in `<DR_REGION>` with its highest committed sequence and the matching output it has consumed, and the objectives are an RPO of 1 min and trading back within 1 h of the start of the outage.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Pilot light: data copies only, compute started after the loss | Lower standing cost | EKS nodes, brokers and writers launched and warmed during the outage | Launch and warm-up sit inside the 1 h RTO |
| Backup restore in the DR region | Lowest standing cost | A cross-Region snapshot copy can take hours, and the log needs its own copy with a consistent boundary to the ledger | Misses the 1 h RTO and the 1 min RPO |
| Active-active regions | No promotion during a region loss | Cross-region consensus on the order path, or two sequences per symbol | Conflicts with REQ-P1-8 and REQ-P1-14A |
| Halt until the region returns | No standing cost and no divergent tail | A long or permanent region loss stops the exchange for as long | No committed RTO for REQ-P1-13A |

## Trade-offs

The warm standby works against COST-DP2: its compute, brokers, database and keys are paid around the clock, 5,239.65 USD per month in the DR column of section 8.3 of `SOLUTION.md`, 29.2 % of the on-demand total. One active region works against PERF-DP2, kept because one order sequence per symbol cannot be written in two regions. A person declares the loss and approves the resume, against REL-DP1, because an automatic promotion during a partial outage could create two ledgers. A DR-region outage pauses withdrawals in the primary, never trading, because the signer lease lives in `<DR_REGION>`.

## Consequences

### Positive

- A region loss has a committed RPO and RTO that the DR exercise measures.
- Public market data and private reads keep working from the DR origin during the outage.
- Promotion needs no answer from ap-southeast-1.

### Negative

- The standby costs money every month whether or not a region fails.
- Orders acknowledged in the last replication window can be lost, and the runbook reports them per shard.
- The old region's tail after the outage needs reconciliation by people, with compensating postings under two approvals.

### Risks

- Replication lag could exceed the RPO. Lag alarms at 30 s on MSK Replicator and on Aurora Global Database page well before 1 min, and the witness reports the loss per shard.
- A NAT, firewall or table fault could stop the witness writes unnoticed and leave the RPO unmeasurable when it has to be reported. Each risk writer exports the age of its last successful witness write and an alert pages above 5 s, and at promotion a witness older than 2 s is reported as stale, with the time after it counted as lost.
- The MSK Replicator pages do not describe how aborted transactions are copied. DR consumers therefore never rely on transaction markers: per input ID only the outputs of the highest fencing token count, deduplicated by event ID.
- The client-path fence uses the CloudFront control plane, which runs in us-east-1, outside both regions, so a simultaneous impairment there would delay the switch.

## Verification

The DR exercise (cloud run) runs with the source region unreachable to operators and to the DR region, with a withdrawal in flight, a withdrawal request that never reached the signer, an aborted matching transaction and an aborted risk transaction whose orders were resent, all in the replicated topics. A second run keeps ap-southeast-1 reachable, as after an MSK cluster loss, and checks that the deny stops the primary signer's renewals. Both measure the RPO through the witness and the RTO end to end, from the start of the outage to the first accepted order, and check that no input ID names two inputs and that no ID issued after promotion equals one issued before it.

## Reopen when

A region-loss RTO under 1 h or an RPO under 1 min becomes a requirement, or a DR exercise misses either objective.
