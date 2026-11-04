# ADR-P5-0008: Encryption in transit and at rest with customer managed keys

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P5-2, REQ-P1-8 |
| Principles | SEC-DP5, SEC-DP6 |
| Supersedes | none |

## Context

Order flow, ledger data and PII cross the network to MSK, Aurora and Valkey. Snapshots and copies of these stores can leave the stores themselves. The wallet path carries the withdrawal requests that move funds. MSK produce has a 30 ms allocation on the order path.

## Decision

Every connection to Aurora, Valkey and MSK uses TLS, each data class has its own KMS customer managed key, and the wallet path uses mTLS.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| AWS managed keys | No key policy work | Key policies cannot separate data classes or limit who may decrypt a copied snapshot | Weaker control over copies (TH-20) |
| mTLS between every service now | Mutual authentication everywhere | A mesh proxy hop on the order path that nobody has measured | Deferred as SC-17 until measured |
| Application-level encryption of PII fields | Protects fields from database operators | Key handling inside the application and harder queries | Not needed while KYC records stay with the vendor (FN-03) |

## Trade-offs

TLS to MSK spends part of the 30 ms produce allocation and stays on in the load test (REQ-P1-8). A key per data class adds key policies to manage.

## Consequences

### Positive

- A copied snapshot cannot be read without the consent of its key policy.
- The wallet path authenticates both ends.

### Negative

- Key policies become part of the review of every new data store.

### Risks

- A broad decrypt grant undoes the separation. The key policy review and the posture findings of SC-11 look for it.

## Verification

Cloud run: the load test with TLS on. Review: key policy review per data class.

## Reopen when

The load test shows MSK produce above its 30 ms allocation with TLS on, or the trigger of SC-17 fires.
