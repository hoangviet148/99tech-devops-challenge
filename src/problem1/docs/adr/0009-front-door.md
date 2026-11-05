# ADR-P1-0009: CloudFront, WAF, Shield Advanced and ALB as the front door

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-4, REQ-P1-7, REQ-P1-8, REQ-P1-2 |
| Principles | PERF-DP2, COST-DP3, SUS-DP6 |
| Supersedes | none |

## Context

About 60 % of the 500 rps is public market data that many clients read at once, and 10,000 WebSocket connections stay open for long sessions. Exchanges are frequent DDoS targets, and an outage during volatility costs revenue and trust. The edge has 10 ms of the latency allocation, measured with every control on. `SOLUTION.md` tracks this record as AD-P1-09.

## Decision

Route 53 points to CloudFront, which serves the SPA from S3, caches public market data for 1 s on a cache key of path, symbol and depth, and forwards private and order routes with caching disabled. AWS WAF with managed, rate-based and bot rules and Shield Advanced protect the distribution, the production account that owns it takes Business Support+ because the Shield Response Team needs a Business or Enterprise Support plan, and the ALB behind it accepts traffic from CloudFront only (Problem 5 SC-10).

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| API Gateway for REST and WebSocket | Managed throttling and usage plans | A WebSocket connection lasts at most 2 hours, and it bills every REST request and every WebSocket message and connection minute | Long market data sessions would be cut at 2 hours, and the bill would grow with every message of the largest traffic class |
| ALB exposed directly | One hop fewer | No edge cache for market data, origin reachable by attackers | Every market data read hits the origin |
| NLB instead of ALB | Layer 4 pass-through, and a capacity unit that covers 100,000 active connections | No HTTP routing: listener rules match the source IP address type only, so WebSocket upgrades on the same hostname and port could not reach a target group of their own | The front door needs HTTP routing per request class |
| Valkey cache without an edge cache | No cache behaviours to manage at the edge | Every public market data request crosses the edge to the ALB and a pod before Valkey answers | Half of the public market data requests (AS-05 of `SOLUTION.md`) would reach the origin instead of the edge cache |
| Shield Standard instead of Advanced | 3,125.79 USD per month less: 2,921.30 net of the WAF fees Advanced removes and 204.49 of support fee on that amount | No DDoS cost protection and no response team during an attack. With Advanced the response team still needs a Business or Enterprise Support plan, which production buys anyway | DDoS risk on an exchange outweighs the fee |

## Trade-offs

Public market data can be up to 1 s old on REST, while WebSocket streams carry every update with sequence numbers. Shield Advanced is a fixed fee that works against COST-DP2: 3,125.79 USD per month with the support fee on it, kept as a recorded trade-off in section 12 of `SOLUTION.md`.

## Consequences

### Positive

- Cached market data never reaches the origin within its 1 s TTL (COST-DP3, SUS-DP6).
- With Shield Advanced, WAF web ACLs, rules and tier 0 requests on the protected distribution cost 0 USD.

### Negative

- The edge is 48.9 % of the estimated on-demand bill. Data transfer out of CloudFront, billed by CloudFront and by Shield, is its largest usage-driven cost, and WebSocket traffic is 26,280 of its 28,908 GB.

### Risks

- A bypass to the ALB would skip WAF. Problem 5 SC-10 makes the ALB internal behind a CloudFront VPC origin, falls back to the CloudFront prefix list with a rotated secret header if the prelaunch WebSocket test through the VPC origin fails, and a test tries to reach the ALB directly.
- The SRT pages name Business Support and Enterprise Support, not Business Support+ (AS-32 of `SOLUTION.md`). AWS Support confirms in writing before launch that Business Support+ engages the SRT, and Enterprise Support, from 5,000 USD per month on the support pricing page, is the fallback.

## Verification

Cache hit ratio in the load test (cloud run), direct-to-ALB bypass test (cloud run).

## Reopen when

A product requirement asks for REST market data fresher than 1 s, or a CloudFront plan covers DDoS cost protection and response for less than the 3,125.79 USD per month of Shield Advanced with its support fee.
