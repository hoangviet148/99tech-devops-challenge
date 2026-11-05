# ADR-P5-0005: Cognito configuration and an admin plane behind Verified Access

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P5-2, REQ-P1-8 |
| Principles | SEC-DP1, SEC-DP6, FSI-DP1, OPS-DP8 |
| Supersedes | none |

## Context

Cognito user pools are the Problem 1 identity provider, and the gateway verifies JWTs locally against cached JWKS. The Cognito pages read on 2026-11-04 say that protection against malicious sign-ins and compromised passwords is in the Plus plan, and that passkeys are in Essentials and Plus. Access tokens last between 5 min and 1 day, and a revoked token still passes local verification of its signature and expiry. The `origin_jti` claim ties an access token to the refresh token that a revocation targets, and managed login keeps a 1 h session cookie that lets a user sign in again without credentials. Operators need admin tools that the internet cannot reach.

## Decision

The user pool runs on the Plus plan with passkeys that require user verification and TOTP, no SMS for step-up, recovery through verified email with a cooldown and support review, 5 min access tokens, and a gateway revocation list keyed by `origin_jti` on withdrawal and key-management calls. A withdrawal needs an `auth_time` within the last 5 min from a passkey or TOTP sign-in. Admin tools sit behind AWS Verified Access with SSO, MFA and device posture, balance adjustments need a second approver, and a break-glass procedure gives access when SSO is unavailable.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Keycloak on EKS on an Aurora Global Database | Identity follows the DR region | The exchange operates its own identity system | OPS-DP8, and Cognito covers the launch needs |
| A revocation check on every request | Instant revocation everywhere | A network call per request on the order path | Breaks REQ-P1-8 |
| Admin tools behind a VPN or a bastion host | Familiar to operators | Network-level access without device posture, and access paths that stay open | Verified Access checks identity and device on every request |

## Trade-offs

SEC-DP1 gives way on trading calls: a revoked access token keeps working there for up to 5 min, which SC-22 records as an accepted risk. Cognito user pools are regional, so the DR runbook uses the cross-region option current at writing time or re-enrolment.

## Consequences

### Positive

- Withdrawals and key changes see a revocation at once.
- Customers use phishing-resistant factors, and step-up never falls back to SMS.
- Operators reach admin tools only from a managed device with SSO and MFA.

### Negative

- The Plus plan costs more than Essentials, which enters the cost comparison.
- Device posture needs one of the device trust providers that Verified Access supports (FN-09).

### Risks

- If a sign-in through the managed login cookie sets a new `auth_time`, the step-up weakens (FN-10). Step-up therefore runs through an API sign-in with a passkey or TOTP challenge until a sandbox test settles it.

## Verification

Review: policy review with denial test cases for the admin plane. Review: the step-up contract as withdrawal policy test cases, and the accepted-risk row of SC-22 with its reason.

## Reopen when

The regulator requires instant revocation of every session, or the sandbox test of FN-10 shows that a cookie sign-in sets a new `auth_time`.
