# Problem 1 architecture decision records

Each record follows the format in `template.md`: context, decision, alternatives with their trade-offs, consequences, verification and the trigger that would reopen it. Requirement IDs refer to [`docs/requirements.md`](../../../../docs/requirements.md), principle IDs to [`docs/principles.md`](../../../../docs/principles.md), and decision IDs such as AD-P1-01 to the traceability section of [`SOLUTION.md`](../../SOLUTION.md).

| ADR | Decision | Status | Date |
|---|---|---|---|
| [ADR-P1-0001](0001-spot-trading-scope.md) | Spot trading subset as the feature scope | accepted | 2026-11-04 |
| [ADR-P1-0002](0002-one-region-three-azs.md) | One region over three AZs with static capacity for an AZ loss | accepted | 2026-11-05 |
| [ADR-P1-0003](0003-ack-at-durable-acceptance.md) | No database call on the order path, acknowledgement at durable acceptance | accepted | 2026-11-04 |
| [ADR-P1-0004](0004-risk-engine-single-writer.md) | Risk engine with one writer per account shard | accepted | 2026-11-05 |
| [ADR-P1-0005](0005-single-threaded-matching.md) | Single-threaded matching per symbol with a fenced hot standby | accepted | 2026-11-05 |
| [ADR-P1-0006](0006-msk-sequencer.md) | Amazon MSK as sequencer and event log, final after a benchmark | accepted | 2026-11-05 |
| [ADR-P1-0007](0007-aurora-ledger-outbox.md) | Aurora PostgreSQL ledger with outbox and checkpoints | accepted | 2026-11-05 |
| [ADR-P1-0008](0008-eks-karpenter.md) | EKS with Karpenter for compute | accepted | 2026-11-05 |
| [ADR-P1-0009](0009-front-door.md) | CloudFront, WAF, Shield Advanced and ALB as the front door | accepted | 2026-11-05 |
| [ADR-P1-0010](0010-cognito-identity.md) | Cognito with multi-Region replication as identity provider | accepted | 2026-11-05 |
| [ADR-P1-0011](0011-valkey-rate-limits.md) | ElastiCache for Valkey for rate limits and market data, with a local fallback | accepted | 2026-11-05 |
| [ADR-P1-0012](0012-backups-and-recovery.md) | Backups, replay horizons and ordered replay | accepted | 2026-11-05 |
| [ADR-P1-0013](0013-slo-observability.md) | SLOs, OpenTelemetry, burn-rate alerts and a dead-man's switch | accepted | 2026-11-05 |
| [ADR-P1-0014](0014-capacity-cost-sustainability.md) | Capacity design point, cost levers and sustainability KPIs | accepted | 2026-11-05 |
| [ADR-P1-0015](0015-scaling-stages.md) | Scaling stages with measured triggers | accepted | 2026-11-05 |
| [ADR-P1-0016](0016-gitops-operating-model.md) | IaC with GitOps and canaries, documented operating model | accepted | 2026-11-05 |
| [ADR-P1-0017](0017-warm-standby-region.md) | Warm standby region with a committed RPO and RTO | accepted | 2026-11-05 |
