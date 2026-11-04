# ADR-P2-0005: Remove the single load balancer VM as a single point of failure

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P2-3 |
| Principles | REL-DP3, OPS-DP8 |
| Supersedes | none |

## Context

Every upstream service is reachable only through this one VM. A full disk, a bad configuration reload, a kernel panic or a retired host takes all of them down at once, and every recovery in the cause catalog runs on the live and only path. The runbook shortens the time to recover. It does not change how much breaks when the VM fails.

## Decision

The answer recommends one of two replacements. Where the upstreams need nothing beyond HTTP routing and health checks, a managed AWS load balancer takes over. Where they need NGINX features, two NGINX instances in an Auto Scaling group across two Availability Zones sit behind a Network Load Balancer, built from one image and one configuration kept in code.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Keep one VM with the runbook and the alerts | No new cost and no migration | Every disk, kernel or host event is an outage of every upstream | Leaves the blast radius as it is |
| Two VMs sharing a floating IP through keepalived | NGINX stays unchanged | Moving an IP inside a VPC needs API calls from the failover script, and a split brain can leave both or neither active | More moving parts than a managed load balancer in front of two instances |
| DNS round robin across two VMs | Simple | Clients cache records of a dead VM, nothing removes it on a failed health check | Fails over slower than a load balancer health check |

## Trade-offs

Both replacements add a monthly cost and a migration that a single VM avoids, which works against COST-DP2 ("Adopt a consumption model") for a service that may carry little traffic. The cost buys availability for every upstream at once, and REQ-P2-3 shows that the impact of each root cause is total while one VM carries all traffic.

## Consequences

### Positive

- One instance can fill its disk, or be replaced, while the other keeps serving.
- A managed load balancer has no disk to fill and no NGINX to patch.

### Negative

- The migration needs a cutover plan for the DNS records and the TLS certificates.
- Two NGINX instances need identical configuration, which only configuration management or an image pipeline keeps true.

### Risks

- A shared bad configuration takes both instances down. Changes roll to one instance first and wait for its health check (OPS-DP4).

## Verification

Review of the recommendation in `SOLUTION.md` (review).

## Reopen when

An availability objective is set for the upstream services, or an incident on the single VM takes down all upstreams at once again.
