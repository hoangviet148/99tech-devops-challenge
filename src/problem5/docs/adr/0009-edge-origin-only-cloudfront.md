# ADR-P5-0009: Edge protection and an origin only CloudFront can reach

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P1-7, REQ-P1-8, REQ-P1-15A |
| Principles | SEC-DP3, REL-DP1 |
| Supersedes | none |

## Context

Problem 1 puts CloudFront, AWS WAF and Shield Advanced in front of an ALB, and a public ALB would let an attacker skip all three. The CloudFront pages read on 2026-11-04 say that an ALB in private subnets can be a VPC origin, and that its security group can admit only the CloudFront service-managed security group, which limits traffic to the distributions of the account. The VPC origin page lists gRPC, Lambda@Edge origin triggers and inbound network ACLs as unsupported and does not list WebSocket. The WebSocket page says WebSocket works with any distribution, yet neither page states WebSocket over a VPC origin in so many words.

## Decision

AWS WAF runs managed, rate-based and bot rules, Shield Advanced covers the edge, and the ALB is internal behind a CloudFront VPC origin that admits only the CloudFront service-managed security group. Private and order routes use a caching-disabled policy that forwards authorization, and public market data uses a cache key of path, symbol and depth with a 1 s TTL. A prelaunch test opens a WebSocket through the VPC origin, and if it fails, the fallback is a public ALB that admits only the CloudFront managed prefix list and checks a rotated secret header.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| A public ALB with WAF attached to it | Simple | Attackers reach the origin directly, outside CloudFront caching and edge capacity | Fails TH-23 |
| A public ALB limited to the CloudFront managed prefix list, with a secret header | Works for every protocol | The ALB stays public, and the header secret needs rotation | Kept as the fallback |
| API Gateway in front of the services | Managed throttling and keys | WebSocket connections end after 2 hours, and the per-request cost enters the Problem 1 comparison | Lost in Problem 1 on the WebSocket limit |

## Trade-offs

Shield Advanced has a fixed monthly fee (REQ-P1-4), kept because exchanges are frequent DDoS targets. WAF and CloudFront sit in the measured path inside the 10 ms edge allocation (REQ-P1-8). Private routes skip the cache, so every private request reaches the origin.

## Consequences

### Positive

- No request reaches the ALB without passing CloudFront and WAF.
- Public market data, the largest request class, comes from the cache.

### Negative

- The origin design relies on a VPC origin feature whose WebSocket support is not stated outright (FN-11).

### Risks

- A rate-based rule blocks a legitimate burst. The rules sit well above normal per-client traffic, and a 429 counts as an error in the load test.

## Verification

Cloud run: the direct-to-ALB bypass test, a WebSocket through the VPC origin, and the load test through the public hostname.

## Reopen when

The WebSocket test through the VPC origin fails, or the restriction list on the VPC origin page changes.
