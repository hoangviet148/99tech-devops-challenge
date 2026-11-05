# ADR-P3-0012: Prometheus metrics, a probe through nginx and tested alert rules

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-4 |
| Principles | OPS-DP2, OPS-DP7, REL-DP2 |
| Supersedes | none |

## Context

Users found every failure of this stack before any signal did: no service had a healthcheck, the API exported nothing, and nginx logged without upstream timings (F10). The report must say which monitoring and alerts to add (REQ-P3-4). An alert that nobody has seen fire is a guess, so each rule needs a test, and the probe that pages needs one run against a real outage.

## Decision

The API exports a request histogram labelled by route template and status class, the pool gauges and a Redis write failure counter on `/metrics`, which nginx does not route. A `monitoring` compose profile adds Prometheus and a blackbox exporter that probes `/api/users` through nginx. Five rules are implemented with `promtool` unit tests, and four more that need telemetry this stack lacks are documented as proposed.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| OpenTelemetry SDK and a collector | One standard for metrics, traces and logs | A collector, an exporter pipeline and more dependencies for a two-endpoint API | The alert set needs four metrics, which `prom-client` covers |
| Alerts from nginx access logs | No change to the API | Needs a log pipeline, and the API's own failures hide behind nginx retries | Log-based rules are listed as proposed instead |
| Grafana dashboards in the profile | A visual for reviewers | Files to review that change nothing that gets detected | Left out, the alert rules are the decision |
| Monitoring in the default stack | One command shows everything | Two more containers for every run of `docker compose up` | A profile keeps the default stack as the template described it |

## Trade-offs

The profile is opt-in, so a reviewer who runs the default stack gets no alerts, which trades OPS-DP2 coverage for a default stack that matches the README. Pages go out only for symptoms users feel (the probe and the 5xx ratio), so a Redis outage raises a ticket and never a page, which accepts slower attention to a degraded but invisible fault (OPS-DP7).

## Consequences

### Positive

- The probe catches every failure that nginx itself generates, including F1, F4 and F5, which the API's own metrics cannot see.
- Every rule has a unit test that fails when the threshold or the expression drifts.

### Negative

- Prometheus keeps 2 days of data inside the container, so the history ends with the container.
- Route labels use a fixed list of paths, so a new route reports as `other` until someone adds it.

### Risks

- Docker DNS discovery finds replicas only while they resolve. A replica that crashed before the scrape disappears from the targets instead of reporting errors, which the probe and the 5xx ratio still catch.

## Verification

`scripts/test-alerts.sh` runs `promtool check config` and `promtool test rules` (offline test). `scripts/monitoring-check.sh` starts the profile, stops nginx and measures the time until `ApiProbeFailing` fires and clears (local run).

## Reopen when

The stack moves to an orchestrator with its own metrics pipeline, or an alert fires in a way its unit test did not predict.
