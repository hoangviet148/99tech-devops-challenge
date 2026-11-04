# ADR-P1-0013: SLOs, OpenTelemetry, burn-rate alerts and a dead-man's switch

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-8 |
| Principles | OPS-DP2, OPS-DP7, GEN-DP5 |
| Supersedes | none |

## Context

The requirements are stated per request class and per stage of the order lifecycle: p99 under 100 ms, order-to-match under 50 ms, settlement under 1 s, 99.95 % availability. Alerts on CPU or on single slow requests page on symptoms users do not feel and miss a slow burn of the error budget. Every page depends on the ruler, the alert manager and the route to the paging service, so a fault in that chain silences every alert at once and looks like a healthy platform. `SOLUTION.md` tracks this record as AD-P1-15.

## Decision

Each requirement becomes an SLO measured from traces, event timestamps and synthetic probes through the public hostname, fed by an OpenTelemetry collector into Amazon Managed Service for Prometheus, Amazon Managed Grafana, CloudWatch Logs and X-Ray. Alerts page on the error-budget burn rate over a short and a long window, every alert links its runbook, and the alert rules have unit tests. An always-firing watchdog rule in the Managed Prometheus ruler reaches the paging service every minute through the SNS receiver of the alert manager, and the paging service pages on a separate path when that heartbeat stops for 5 min.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Threshold alerts per service on CPU and latency | Simple to write | Pages that need no action, slow burns missed | Alert fatigue without user focus |
| Self-managed Prometheus, Grafana and a tracing backend on EKS | No per-sample fees | Storage, retention and high availability to operate | More operations for the same signals (OPS-DP8) |
| Burn-rate alerts without a heartbeat | One rule and one route fewer | A broken ruler, alert manager or route stops every page without any signal | A silent alert path reads as a healthy platform |

## Trade-offs

Telemetry costs 674.02 USD per month in the estimate of section 8.3 of `SOLUTION.md`, 3.8 % of the on-demand total, accepted for the actionable signals of OPS-DP2. Burn-rate alerts react later than a raw threshold to a short spike that does not threaten the budget, by design. The watchdog adds a paging path outside the chain it watches, so under OPS-DP7 a silent chain is found within 5 min instead of at the next incident.

## Consequences

### Positive

- Pages map to user-visible objectives, and each one has a runbook.
- SLO reviews feed the scaling triggers and the operating model (OPS-DP7).
- A failure of the alerting chain pages within 5 min.

### Negative

- Every new route needs its request class and SLO before launch.
- The paging service runs a heartbeat check of its own, a second configuration to keep in step.

### Risks

- A missing trace context hides a slow hop. The load test checks that every hop of section 7.1 appears in traces.

## Verification

Alert rule unit tests in the design, the watchdog rule and its heartbeat route included (review).

## Reopen when

Observability lines exceed 10 % of the monthly bill, or more than 2 pages per week over a quarter close without action.
