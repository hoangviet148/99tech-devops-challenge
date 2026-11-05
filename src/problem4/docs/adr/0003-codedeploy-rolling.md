# ADR-P4-0003: Backend deploy through CodeDeploy in-place rolling with fleet checks

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-1, REQ-P4-4 |
| Principles | OPS-DP4, OPS-DP6, OPS-DP8, REL-DP1 |
| Supersedes | none |

## Context

The backend runs as a systemd service on an Auto Scaling group of at least 2 instances across 2 AZs behind an ALB, on Amazon Linux 2023 x86_64 (A2). A deploy must not cause an outage. It must also undo itself when the release fails. The CodeDeploy documentation on deployment configurations states that with `CodeDeployDefault.OneAtATime` a deployment still succeeds when only the last instance fails, so its status alone cannot gate a release.

## Decision

`scripts/deploy-backend.sh` creates a CodeDeploy in-place deployment with `CodeDeployDefault.OneAtATime`, pinned to the S3 VersionId of `backend/<sha>.tgz` once the object's checksum matches the build digest. After the waiter returns, it requires every deployment target to be `Succeeded`, at least one ALB target `healthy` with every other one `healthy` or `draining`, no G5 alarm that entered ALARM during the deployment, and `/version` to report the release SHA. On any miss it redeploys the previous recorded release, unless the compatibility gate of ADR-P4-0007 vetoes it, and a manual rollback must name a release the environment ran before, redeployed from the object version recorded then.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| CodeDeploy blue/green with a copied Auto Scaling group | Traffic switches back at once | Doubles the instances during each deploy | Upgrade path once rollback speed matters more than cost |
| Packer AMI with an instance refresh | Immutable instances | An AMI build in every release | Fits once OS changes ship with the app |
| SSM Run Command pulling the bundle | No CodeDeploy agent | No traffic draining and no built-in rollback | Both would be hand-written |
| SSH or rsync from the runner | Familiar tooling | Inbound SSH and a long-lived key | Conflicts with G7 |

## Trade-offs

In-place rolling takes one instance out of service at a time. A rollback is a second rolling deployment, as slow as the first, where blue/green would restore the old release at once (REL-DP1) at the cost of a second fleet during every deploy. The fleet checks keep the cheaper option safe (OPS-DP6).

## Consequences

### Positive

- A failed last instance, an unhealthy target or a wrong SHA behind the ALB starts a rollback. The deployment status alone would miss all three.
- `ApplicationStop` runs from the previous revision, so the first release ships a stop hook that tolerates a missing service.
- `ValidateService` waits up to 60 s for `/healthz` on each instance and compares `/version` with the release SHA.
- A release that raises the 5xx or unhealthy-host alarm while it rolls out returns to the previous release, even when every instance passed `ValidateService`.
- Exit codes separate the outcomes: 0 deployed, 1 failed before the deployment started, 3 rolled back, 4 rollback failed, 5 rollback vetoed.

### Negative

- The smoke test reaches one instance through the ALB, so the SHA check across the fleet rests on the `ValidateService` result of each target.
- A target that drains during the check, for example after a scale-in, does not fail it. Lost capacity is left to the `UnHealthyHostCount` alarm.
- The alarms are read once, after the fleet checks. A bad release can therefore reach every instance before the script returns to the previous one, where alarms attached to the deployment group would stop the rollout at the instance that raised them.

### Risks

- The G5 alarms on `HTTPCode_Target_5XX_Count` and `UnHealthyHostCount` live in `infra/terraform/modules/backend`, outside the deployment group. Attached to the group, they would stop the first deploy while instances without a release keep `UnHealthyHostCount` raised, and they would stop the return to the previous release while the failed one keeps an alarm raised. Overriding that per deployment needs `codedeploy:UpdateDeploymentGroup`, which would let the deploy role rewrite its own group. The script therefore ignores an alarm that was raised before the deployment, and it reads no alarm on the first deploy or on a return.
- An alarm needs 2 or 3 one-minute periods to change state, so a regression that starts on the last instance can pass the check and only notify through `alarm_actions`.

## Verification

`scripts/tests/test-deploy-backend.sh` runs the deploy against the fake `aws` CLI for a healthy fleet, a failed last instance, a failed smoke test, an alarm raised during the deploy, an alarm raised before it, a first deploy beside a raised alarm, a draining target, a fleet with no healthy target, a wrong checksum, a missing artifact, a vetoed rollback and a rollback to a release the environment never ran (offline test). `scripts/tests/test-hooks.sh` runs the hooks in an `amazonlinux:2023` container with a stub `systemctl` (offline test). Deployments to real instances belong to the AWS acceptance plan (cloud run).

## Reopen when

A cloud run shows a rolling rollback that outlasts the time the service owner accepts a bad release in production, or OS changes start shipping together with the app.
