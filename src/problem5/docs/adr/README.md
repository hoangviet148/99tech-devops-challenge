# Problem 5 architecture decision records

Each record follows the format in `template.md`: context, decision, alternatives with their trade-offs, consequences, verification and the trigger that would reopen it. Requirement, principle, threat and change IDs refer to [SOLUTION.md](../../SOLUTION.md).

| ADR | Decision | Status | Date |
|---|---|---|---|
| [ADR-P5-0001](0001-stride-over-trust-boundaries.md) | STRIDE over trust boundaries, ranked by impact on funds | accepted | 2026-11-04 |
| [ADR-P5-0002](0002-custody-boundary-signer.md) | Custody boundary: signer service with KMS keys in a wallet account | accepted | 2026-11-04 |
| [ADR-P5-0003](0003-withdrawal-controls-integrity-halts.md) | Withdrawal controls and integrity halts | accepted | 2026-11-04 |
| [ADR-P5-0004](0004-signed-api-requests.md) | Signed API requests with nonce, window and durable idempotency | accepted | 2026-11-04 |
| [ADR-P5-0005](0005-cognito-and-admin-plane.md) | Cognito configuration and an admin plane behind Verified Access | accepted | 2026-11-04 |
| [ADR-P5-0006](0006-multi-account-organization.md) | Multi-account organization with SCPs | accepted | 2026-11-04 |
| [ADR-P5-0007](0007-network-segmentation-egress.md) | Network segmentation and egress allowlist | accepted | 2026-11-04 |
| [ADR-P5-0008](0008-encryption-customer-managed-keys.md) | Encryption in transit and at rest with customer managed keys | accepted | 2026-11-04 |
| [ADR-P5-0009](0009-edge-origin-only-cloudfront.md) | Edge protection and an origin only CloudFront can reach | accepted | 2026-11-04 |
| [ADR-P5-0010](0010-detection-audit-locked-backups.md) | Detection, immutable audit and locked backups | accepted | 2026-11-04 |
| [ADR-P5-0011](0011-signed-images-kyverno.md) | Signed images admitted by Kyverno | accepted | 2026-11-04 |
| [ADR-P5-0012](0012-msk-iam-authorization.md) | MSK authorization through IAM policies | accepted | 2026-11-04 |
| [ADR-P5-0013](0013-launch-gates.md) | Compliance and prelaunch exercises as launch gates | accepted | 2026-11-04 |
| [ADR-P5-0014](0014-deferred-and-accepted-risks.md) | Deferred controls and accepted risks with reopen triggers | accepted | 2026-11-04 |
