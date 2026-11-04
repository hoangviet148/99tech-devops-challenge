# ADR-P1-0014: Capacity design point, cost levers and sustainability KPIs

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-4 |
| Principles | COST-DP1, COST-DP3, COST-DP5, SUS-DP1, SUS-DP2, SUS-DP4 |
| Supersedes | none |

## Context

The static capacity of ADR-P1-0002 fixes a baseline that runs around the clock. Discounts differ per service: the Savings Plans eligible-services page lists only EC2, Fargate and Lambda for Compute Savings Plans, Aurora and ElastiCache offer reserved capacity, and the MSK price list has on-demand terms only. The estimate in section 8.3 of `SOLUTION.md` shows the edge at 56.8 % of the bill. `SOLUTION.md` tracks this record as AD-P1-13, AD-P1-14 and AD-P1-21.

## Decision

The design uses Graviton instances, 1-year Compute Savings Plans for the EC2 baseline, 1-year reserved capacity for Aurora and ElastiCache, Spot only outside the trading path, and VPC endpoints where traffic pays for them. Cost allocation tags per service and environment feed Cost Explorer, and two sustainability KPIs, vCPU-hours per 1,000 orders and GB stored per active user, come monthly from the cost and usage report and the Customer Carbon Footprint Tool.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| On demand only | No commitment while load is unknown | 897.89 USD per month more in the estimate | The baseline is fixed by the AZ-loss design point anyway |
| 3-year commitments | Deeper discount | Locks the baseline before the first load test | Too early for measured load |
| Spot for the stateless trading path | Cheapest compute | Interruptions on the latency path during volatility | Spot stays on batch and analytics work |

## Trade-offs

Commitments work against COST-DP2 for the baseline, a recorded trade-off in section 13 of `SOLUTION.md`. The commitments save only 5.8 % because most of the spend is data transfer, requests, MSK and fixed fees, so the largest lever is measuring WebSocket traffic, where each 0.1 KB/s per connection moves 328.50 USD per month.

## Consequences

### Positive

- Every dollar is attributable to a service and an environment (COST-DP5).
- Interface endpoints are added where traffic pays for them: one endpoint in 3 AZs costs 28.47 USD per month and pays off above 581 GB per month.

### Negative

- Commitments must be reviewed when the architecture changes, for example at a scaling stage.

### Risks

- Assumed quantities could be wrong by a large factor. The first month of the cost and usage report replaces every quantity in the estimate.

## Verification

Cost table in section 8.3 of `SOLUTION.md` (review), Cost Explorer by tag (review), monthly KPI review (review).

## Reopen when

At each quarterly cost review, baseline load changed by more than 20 %.
