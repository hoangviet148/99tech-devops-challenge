# ADR-P1-0010: Cognito with multi-Region replication as identity provider

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-1, REQ-P1-6, REQ-P1-8, REQ-P1-4, REQ-P1-13A |
| Principles | OPS-DP8, COST-DP4, SEC-DP1, REL-DP2 |
| Supersedes | none |

## Context

Signup and login with MFA are in scope, and identity is not where the exchange competes. The gateway must verify tokens without a network call per request to stay inside its 5 ms allocation. Cognito user pools are regional, and the 1 h of REQ-P1-13A for a region loss leaves no time for every user to enroll again in a new pool. Cognito multi-Region replication keeps a replica user pool in one more Region, needs the Essentials or Plus plan and a multi-Region customer managed key, and lets a replica serve sign-in and token refresh, while sign-up, password resets, profile changes and TOTP stay with the primary. `SOLUTION.md` tracks the identity provider under AD-P1-08 and its multi-Region replication under AD-P1-10.

## Decision

Amazon Cognito user pools on the Plus plan of Problem 5 SC-22 handle signup, login and MFA, and the gateway verifies JWTs against cached JWKS. The multi-Region replication add-on keeps a replica user pool in `<DR_REGION>`, encrypted with the multi-Region customer managed KMS key that the add-on requires, so registered users keep signing in after a region loss. The factors, revocation and step-up rules follow Problem 5 SC-22.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Keycloak on EKS with Aurora Global Database | Follows the DR region with the rest of the data | An identity system to operate, patch and scale | Operations cost for a non-differentiating function |
| An identity service built in-house | Full control of flows | Password storage, MFA and recovery flows to build and audit | Security risk without product benefit |
| Regional user pool with re-enrolment after a region loss | No add-on fee and no multi-Region key | Every user enrolls again in a new pool, with new MFA factors, during the outage | Re-enrolment does not fit the 1 h of REQ-P1-13A |

## Trade-offs

The add-on works against COST-DP2: `<MAU>` x 0.006 USD per month in the DR column of section 8.3 of `SOLUTION.md`, paid whether or not a region fails. A locally verified access token stays valid until it expires, which works against SEC-DP1, so Problem 5 SC-22 keeps access tokens at 5 min and checks a revocation list on withdrawal and key calls. REL-DP2 is served by signing in through the replica in every DR exercise.

## Consequences

### Positive

- Token verification costs no network round trip on the order path.
- AWS runs the identity store, its scaling and its MFA flows.
- Registered users can sign in and refresh tokens through the replica during a region loss.

### Negative

- During a region loss nobody can sign up, reset a password or change a profile until the primary returns, because the replica serves authentication only.
- The cost grows with monthly active users, which are still open (AS-35 of `SOLUTION.md`).

### Risks

- A replica does not support TOTP, so a user whose only second factor is TOTP and whose session has ended cannot sign in during a region loss. Problem 5 SC-22 also offers passkeys, and the DR exercise counts failed sign-ins by factor.
- Tokens from the replica must pass the DR gateway's checks. The user pool uses the updated issuer that the replication page recommends, and the DR exercise signs in through the replica.

## Verification

Service table in section 5 of `SOLUTION.md` (review), Problem 5 SC-22 test cases (review), and sign-in and token refresh through the replica in the DR exercise (cloud run).

## Reopen when

The regulator requires instant revocation of every session, a DR exercise finds a user who cannot sign in through the replica with a factor that the replica supports, or the users whose only second factor is TOTP pass `<TOTP_ONLY_SHARE>` of monthly active users (AS-36 of `SOLUTION.md`).
