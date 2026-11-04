# ADR-P5-0002: Custody boundary: signer service with KMS keys in a wallet account

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P5-3, REQ-P1-14A, REQ-P1-6 |
| Principles | SEC-DP1, SEC-DP3, SEC-DP6, FSI-DP3 |
| Supersedes | none |

## Context

Problem 1 keeps the hot keys in KMS as secp256k1 keys (key spec `ECC_SECG_P256K1`) in a separate wallet account. KMS signs whatever digest it receives: with the message type `DIGEST` it skips the hashing step (KMS Sign page, read 2026-11-04). A key policy can therefore say who may sign, but not what gets signed. Any principal with `kms:Sign` on a hot key can empty the hot wallet.

## Decision

A signer service in the wallet account is the only principal with `kms:Sign` on the hot keys, and the key policy also requires the signing algorithm and the wallet account's VPC endpoint. The signer builds each transaction and its digest from a single-use approval over the canonical fields and enforces the withdrawal policy and the custody protocol of SOLUTION.md section 7. The hot wallet stays under its cap, with sweeps to multi-signature cold storage whose keys stay offline.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Production services call `kms:Sign` under IAM conditions | No extra service | KMS cannot check the transaction behind a digest, so any compromised service with the permission can drain the hot wallet | Fails TH-01 |
| CloudHSM | Single-tenant HSMs under the exchange's control | More operations work for the cluster, its clients and key backups | KMS with a signer meets the same threats with less operating work. The option stays open if a regulator asks for dedicated HSMs |
| Third-party custodian | Custody risk and insurance move into a contract | Withdrawal limits and latency depend on the vendor | A business decision, kept as FN-02 in the facts table |

## Trade-offs

The policy check runs in an isolated account and not in an enclave, which is a present exception to SEC-DP6 that SC-20 defers. The KMS multi-Region replica in the DR region widens the key footprint in exchange for REQ-P1-13A. KMS charges per signature, which enters the cost comparison (REQ-P1-4).

## Consequences

### Positive

- A compromise of the production account cannot sign.
- The signer has one job, which keeps its code small enough for a full review.
- The hot wallet cap bounds the loss from a full compromise of the signer.

### Negative

- The signer is one enforcement point, so a bug in its policy check can approve a bad transaction.
- Withdrawals depend on one more service.

### Risks

- A compromise inside the wallet account signs a theft. The cap bounds it, the reconciliation of the broadcast log with the chains detects it, and SC-15 rehearses the response.
- A lost hot key stops withdrawals. The cold wallet does not depend on KMS and funds a new hot key.

## Verification

Review: the state machine of SOLUTION.md section 7 with approval-reuse and wrong-field test cases. Review: policy denial test cases, including a `kms:Sign` call from any role other than the signer.

## Reopen when

A penetration test bypasses the signer policy inside its account, which brings Nitro Enclaves forward (SC-20), or the custody model decision (FN-02) picks a third-party custodian.
