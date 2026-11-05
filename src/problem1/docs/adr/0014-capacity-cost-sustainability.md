# ADR-P1-0014: Capacity design point, cost levers and sustainability KPIs

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-4 |
| Principles | COST-DP1, COST-DP3, COST-DP5, SUS-DP1, SUS-DP2, SUS-DP4 |
| Supersedes | none |

## Context

The static capacity of ADR-P1-0002 fixes a baseline that runs around the clock. Discounts differ per service: the Savings Plans eligible-services page lists only EC2, Fargate and Lambda for Compute Savings Plans, Aurora and ElastiCache offer reserved capacity, and the MSK price list has on-demand terms only. The estimate in section 8.3 of `SOLUTION.md` shows the edge at 48.9 % of the on-demand bill, and Network Firewall waives the NAT charges on its path but bills every GB it inspects. `SOLUTION.md` tracks this record as AD-P1-13, AD-P1-14 and AD-P1-21.

## Decision

The design uses Graviton instances, 1-year Compute Savings Plans for the EC2 baseline, 1-year reserved capacity for Aurora and ElastiCache, Spot only outside the trading path, gateway endpoints for S3 and DynamoDB, which carry no charge, and interface endpoints where traffic pays for them. Cost allocation tags per service and environment feed Cost Explorer, and two sustainability KPIs, vCPU-hours per 1,000 orders and GB stored per active user, come monthly from the cost and usage report and the Customer Carbon Footprint Tool.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| On demand only | No commitment while load is unknown | 1,230.32 USD per month more in the estimate | The baseline is fixed by the AZ-loss design point anyway |
| 3-year commitments | Deeper discount | Locks the baseline before the first load test | Too early for measured load |
| Spot for the stateless trading path | Cheapest compute | Interruptions on the latency path during volatility | Spot stays on batch and analytics work |
| NAT gateways and Network Firewall for all AWS API traffic | No endpoint hours, one egress path to inspect | Network Firewall bills 0.065 USD per GB on that path, where an interface endpoint bills 0.01 USD, and the NAT charges are waived | An endpoint in 3 AZs costs less above 518 GB per month, and the endpoints of Problem 5 SC-08 keep image pulls, keys, tokens and secrets off the egress path at any volume |

## Trade-offs

Commitments work against COST-DP2 for the baseline, a recorded trade-off in section 12 of `SOLUTION.md`. The commitments save only 6.9 % because most of the spend is data transfer, requests, MSK, the support fee and fixed fees, so the largest lever is measuring WebSocket traffic: running the model at 1.1 instead of 1.0 KB/s per connection raises the on-demand total by 373.99 USD per month.

## Consequences

### Positive

- Every dollar is attributable to a service, an environment and an account (COST-DP5).
- Interface endpoints are added where traffic pays for them: one endpoint in 3 AZs costs 28.47 USD per month and costs less than the NAT and Network Firewall path above 518 GB per month, while gateway endpoints for S3 and DynamoDB cost nothing.

### Negative

- Commitments must be reviewed when the architecture changes, for example at a scaling stage.
- The support fee grows with the production bill, by 7 % of every USD between 10,000 and 80,000 USD a month.

### Risks

- Assumed quantities could be wrong by a large factor. The first month of the cost and usage report replaces every quantity in the estimate, each named by its assumption in section 2.3 of `SOLUTION.md`.

## Verification

Cost table in section 8.3 of `SOLUTION.md` (review), Cost Explorer by tag (cloud run), monthly KPI review (cloud run).

## Reopen when

At each quarterly cost review, baseline load changed by more than 20 %, or telemetry on the NAT and Network Firewall path passes the 518 GB per month above which an endpoint costs less.
