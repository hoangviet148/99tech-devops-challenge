# ADR-P1-0013: SLOs, OpenTelemetry and burn-rate alerts

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-2, REQ-P1-8 |
| Principles | OPS-DP2, OPS-DP7, GEN-DP5 |
| Supersedes | none |

## Context

The requirements are stated per request class and per stage of the order lifecycle: p99 under 100 ms, order-to-match under 20 ms, settlement under 1 s, 99.95 % availability. Alerts on CPU or on single slow requests page on symptoms users do not feel and miss a slow burn of the error budget. `SOLUTION.md` tracks this record as AD-P1-15.

## Decision

Each requirement becomes an SLO measured from traces, event timestamps and synthetic probes through the public hostname. An OpenTelemetry collector feeds Amazon Managed Service for Prometheus, Amazon Managed Grafana, CloudWatch Logs and X-Ray, and alerts page on the error-budget burn rate over a short and a long window. Every alert links its runbook, and the alert rules have unit tests.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Threshold alerts per service on CPU and latency | Simple to write | Pages that need no action, slow burns missed | Alert fatigue without user focus |
| Self-managed Prometheus, Grafana and a tracing backend on EKS | No per-sample fees | Storage, retention and high availability to operate | More operations for the same signals (OPS-DP8) |

## Trade-offs

Telemetry costs 674.02 USD per month in the estimate of section 8.3 of `SOLUTION.md`, 4.4 % of the total, and that cost is accepted. Burn-rate alerts react later than a raw threshold to a short spike that does not threaten the budget, by design.

## Consequences

### Positive

- Pages map to user-visible objectives, and each one has a runbook.
- SLO reviews feed the scaling triggers and the operating model (OPS-DP7).

### Negative

- Every new route needs its request class and SLO before launch.

### Risks

- A missing trace context hides a slow hop. The load test checks that every hop of section 7.1 appears in traces.

## Verification

Alert rule unit tests (offline test).

## Reopen when

Observability lines exceed 10 % of the monthly bill, or more than 2 pages per week over a quarter close without action.
