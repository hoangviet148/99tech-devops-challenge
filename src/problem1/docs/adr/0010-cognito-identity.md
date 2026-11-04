# ADR-P1-0010: Cognito as identity provider

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-1, REQ-P1-6, REQ-P1-8, REQ-P1-4 |
| Principles | OPS-DP8, COST-DP4, SEC-DP1 |
| Supersedes | none |

## Context

Signup and login with MFA are in scope, and identity is not where the exchange competes. The gateway must verify tokens without a network call per request to stay inside its 5 ms allocation. Cognito user pools are regional, so a region loss needs a recovery path for identity too. `SOLUTION.md` tracks this record under AD-P1-08.

## Decision

Amazon Cognito user pools handle signup, login and MFA, and the gateway verifies JWTs against cached JWKS. The feature plan, factors, revocation and step-up rules follow SC-22 in Problem 5.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Keycloak on EKS with Aurora Global Database | Follows the DR region with the rest of the data | An identity system to operate, patch and scale | Operations cost for a non-differentiating function |
| An identity service built in-house | Full control of flows | Password storage, MFA and recovery flows to build and audit | Security risk without product benefit |

## Trade-offs

Regional user pools work against REL-DP1 for region loss: the recovery procedure uses the cross-region option current at the time of the exercise, or re-enrolment. A locally verified access token stays valid until it expires, so SC-22 keeps access tokens at 5 min and checks a revocation list on withdrawal and key calls.

## Consequences

### Positive

- Token verification costs no network round trip on the order path.
- AWS runs the identity store, its scaling and its MFA flows.

### Negative

- Login stays dependent on one region.

### Risks

- A region loss could block logins longer than trading recovery. The first DR exercise measures it.

## Verification

Service table in section 5 of `SOLUTION.md` (review), SC-22 test cases in Problem 5 (review).

## Reopen when

The regulator requires instant revocation of every session, or the first DR exercise misses its objective because of identity.
