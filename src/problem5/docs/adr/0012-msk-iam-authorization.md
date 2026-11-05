# ADR-P5-0012: MSK authorization through IAM policies

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P5-2, REQ-P1-14A |
| Principles | SEC-DP1, SEC-DP3 |
| Supersedes | none |

## Context

MSK carries the order flow, the matching input and the ledger events. A service that can produce to the wrong topic forges inputs, and a service that can consume the wrong topic reads order flow. The MSK page read on 2026-11-04 says that Kafka ACLs have no effect on authorization for IAM identities, that IAM access control does not apply to ZooKeeper nodes, and that MSK logs access events for audit.

## Decision

Clients authenticate through IAM access control, and IAM policies per service role scope cluster, topic, consumer group and transactional ID resources. Tests try forbidden produce and consume calls.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| SASL/SCRAM with Kafka ACLs | Kafka-native authorization | A password per client in Secrets Manager, each with its own rotation | Long-lived credentials (SEC-DP1) |
| Mutual TLS client certificates with Kafka ACLs | No passwords | A private certificate authority and a certificate lifecycle per client | More to run than IAM, which Pod Identity already provides |
| IAM authentication with Kafka ACLs for authorization | A familiar ACL model | The ACLs do nothing for IAM identities | A gap that looks like a control |

## Trade-offs

Authorization depends on IAM and on the changes MSK makes to Kafka, so a move away from MSK means rebuilding it (OPS-DP8 lock-in accepted). Transactional IDs per shard must match the IAM resource patterns, which ties naming to policy.

## Consequences

### Positive

- Each service reaches only its own topics and consumer groups.
- Only the risk engine role can write the account shard partitions.

### Negative

- Every new topic needs a policy change.

### Risks

- ZooKeeper nodes sit outside IAM. If the cluster has them, they accept connections only from the brokers (FN-12).

## Verification

Review: policy review with denial test cases per role, such as a produce call to a topic outside the role and a consume call from another service's group.

## Reopen when

A client that cannot use IAM authentication, such as a third-party connector, needs access to the cluster.
