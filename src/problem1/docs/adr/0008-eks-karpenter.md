# ADR-P1-0008: EKS with Karpenter for compute

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-3, REQ-P1-4 |
| Principles | REL-DP3, REL-DP4, GEN-DP1, SUS-DP3 |
| Supersedes | none |

## Context

The matching engines and risk writers need dedicated, pinned cores to keep latency predictable. The stateless services need to scale with request rate and Kafka lag, and the platform needs shared tooling for GitOps, admission policies and event-driven scaling. Lambda cold starts sit badly on a 100 ms p99 path. `SOLUTION.md` tracks this record as AD-P1-07.

## Decision

EKS runs over 3 AZs with Karpenter provisioning Graviton nodes for the stateless pools, Spot capacity only outside the trading path, and a dedicated compute-optimized pool with static CPU pinning for matching and risk. Every service has topology spread constraints and a disruption budget.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| ECS on Fargate | No nodes to manage | No CPU pinning for the matching engine, no shared tooling such as Argo CD, Kyverno and KEDA | Matching latency and platform tooling |
| ECS on EC2 | No control plane fee, simpler than Kubernetes | Separate tooling for GitOps and admission control | Kept as the cost comparison column of section 8.3 |
| Lambda | Pay per request | Cold starts on the latency path, no long-lived WebSocket or matching processes | Breaks REQ-P1-8 on cold paths |

## Trade-offs

EKS works against OPS-DP8: more to operate than ECS on Fargate, including cluster upgrades and add-ons. The EKS control plane costs 73.00 USD per month (section 8.3 of `SOLUTION.md`), which ECS on EC2 would not.

## Consequences

### Positive

- One platform hosts pinned engines and elastic stateless services, with Karpenter adding nodes for bursts (REL-DP4).
- Argo CD, Kyverno and KEDA run once for every team.

### Negative

- EKS version upgrades become a recurring platform task.

### Risks

- A cluster-wide failure affects every service. GitOps rebuilds the cluster from Git, and the platform team runs the upgrade in a non-production cluster first.

## Verification

The cost comparison column of section 8.3 in `SOLUTION.md` (review).

## Reopen when

The AD-P1-20 benchmark shows that CPU pinning is not needed, or the cluster causes more than 2 pages per week over a quarter.
