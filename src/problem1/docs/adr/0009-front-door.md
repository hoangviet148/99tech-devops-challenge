# ADR-P1-0009: CloudFront, WAF, Shield Advanced and ALB as the front door

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-4, REQ-P1-7, REQ-P1-8, REQ-P1-2 |
| Principles | PERF-DP2, COST-DP3, SUS-DP6 |
| Supersedes | none |

## Context

About 60 % of the 500 rps is public market data that many clients read at once, and 10,000 WebSocket connections stay open for long sessions. Exchanges are frequent DDoS targets, and an outage during volatility costs revenue and trust. The edge has 10 ms of the latency allocation, measured with every control on. `SOLUTION.md` tracks this record as AD-P1-09.

## Decision

Route 53 points to CloudFront, which serves the SPA from S3, caches public market data for 1 s on a cache key of path, symbol and depth, and forwards private and order routes with caching disabled. AWS WAF with managed, rate-based and bot rules and Shield Advanced protect the distribution, and the ALB behind it accepts traffic from CloudFront only (SC-10 in Problem 5).

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| API Gateway for REST and WebSocket | Managed throttling and usage plans | A WebSocket connection lasts at most 2 hours, and every request is billed | Long market data sessions and the request bill at 1.314 billion requests per month |
| ALB exposed directly | One hop fewer | No edge cache for market data, origin reachable by attackers | Every market data read hits the origin |
| Shield Standard instead of Advanced | 2,921.30 USD per month less, net of the WAF fees Advanced removes | No DDoS cost protection and no response team during an attack | DDoS risk on an exchange outweighs the fee |

## Trade-offs

Public market data can be up to 1 s old on REST, while WebSocket streams carry every update with sequence numbers. Shield Advanced is a fixed fee that works against COST-DP2, kept as a recorded trade-off in section 13 of `SOLUTION.md`.

## Consequences

### Positive

- Cached market data never reaches the origin within its 1 s TTL (COST-DP3, SUS-DP6).
- With Shield Advanced, WAF web ACLs, rules and tier 0 requests on the protected distribution cost 0 USD.

### Negative

- The edge is 56.8 % of the estimated monthly bill, driven by WebSocket data transfer.

### Risks

- A bypass to the ALB would skip WAF. SC-10 in Problem 5 makes the ALB internal behind a CloudFront VPC origin, falls back to the CloudFront prefix list with a rotated secret header if the prelaunch WebSocket test through the VPC origin fails, and a test tries to reach the ALB directly.

## Verification

Cache hit ratio in the load test (cloud run), direct-to-ALB bypass test (cloud run).

## Reopen when

A product requirement asks for REST market data fresher than 1 s, or a CloudFront plan covers DDoS cost protection and response for less than Shield Advanced.
