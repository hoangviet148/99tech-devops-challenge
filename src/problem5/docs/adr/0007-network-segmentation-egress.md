# ADR-P5-0007: Network segmentation and egress allowlist

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P5-2, REQ-P1-4, REQ-P1-8 |
| Principles | SEC-DP3, OPS-DP8 |
| Supersedes | none |

## Context

A compromised pod tries two things: reach other services, and send data out. Problem 1 already places the services in a VPC with endpoints for S3, ECR, STS, KMS and Secrets Manager, and its sizing includes Network Firewall endpoints for egress. The order path crosses the gateway, the order service and MSK, and every hop there costs latency.

## Decision

Workloads run in private subnets with a security group per service and a Kubernetes NetworkPolicy that denies by default. AWS APIs are reached through VPC endpoints, and the remaining internet egress passes a Network Firewall allowlist, which sits on egress only.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| A NAT gateway without filtering | Simplest egress | A compromised pod reaches any destination | Fails TH-18 |
| Network Firewall on traffic between services too | Inspection inside the VPC | A firewall hop on the order path and cost per GB on the busiest flows | Breaks the latency allocation (REQ-P1-8) |
| A forward proxy on EKS for egress | Rules per service identity | Another service to run and scale | The managed firewall needs less operating work (OPS-DP8) |

## Trade-offs

Network Firewall costs money per GB processed (REQ-P1-4). Traffic between services gets no inspection and, outside the wallet path, no mutual TLS while SC-17 is deferred, so lateral movement meets only NetworkPolicy and security groups (SEC-DP5).

## Consequences

### Positive

- Exfiltration needs an allowlisted destination.
- A pod reaches only the services its NetworkPolicy and security group allow.

### Negative

- Each new external dependency needs an allowlist change.

### Risks

- An allowlisted domain also hosts content an attacker controls. Allowlist entries go through review like code.

## Verification

Review: policy review with denial test cases, such as a pod that connects to a destination outside the allowlist.

## Reopen when

The penetration test finds lateral movement or exfiltration, or the firewall cost passes its line in the security column of the cost comparison.
