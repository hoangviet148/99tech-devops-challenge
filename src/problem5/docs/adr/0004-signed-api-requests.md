# ADR-P5-0004: Signed API requests with nonce, window and durable idempotency

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P1-8, REQ-P1-14A |
| Principles | SEC-DP1, REL-DP1 |
| Supersedes | none |

## Context

API clients trade and withdraw with keys. A captured request can be replayed while it is valid, and a stolen key acts until it is revoked. The nonce store is a replicated Valkey cluster, and replicas receive writes asynchronously, so a failover can lose the newest entries (ElastiCache replication page, read 2026-11-04). The gateway has 5 ms in the Problem 1 latency allocation and no database call on the order path.

## Decision

Signatures cover method, path, query, body hash, timestamp and nonce, a request is valid from 30 s in the past to 5 s in the future, and nonces are scoped per key and inserted with `SET NX` and a 35 s TTL. Orders also carry the durable client order ID and withdrawals a durable withdrawal ID, so a nonce lost in a failover opens no replay, and withdrawals fail closed while the nonce store is down. Keys have separate trade and withdraw scopes, rotation, revocation and an IP allowlist for the withdraw scope.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Bearer API keys over TLS | Simplest for clients | A captured request or a stolen key replays freely | Fails TH-14 |
| Durable nonce writes, through ElastiCache durability with synchronous writes or through MemoryDB | No nonce lost in a failover | Higher write latency on the gateway hop, which has 7 ms in total | The durable IDs already close the failover gap for orders and withdrawals |
| A client certificate per API key | Strong client authentication without nonces | A certificate lifecycle for every customer and every bot | Pushes PKI work onto customers |

## Trade-offs

Withdrawals stop while the nonce store is down, a REL-DP1 cost accepted to keep funds safe. The gateway allocation grows from 5 to 7 ms of the 100 ms target (REQ-P1-8).

## Consequences

### Positive

- A replay outside the window fails on the timestamp, and one inside the window fails on the nonce or on the durable ID.
- A trade-scoped key cannot withdraw.

### Negative

- Clients must keep their clocks inside the window.
- Nonce store availability joins the failover tests.

### Risks

- Clock skew at clients causes rejections. The signature failure rate per key shows it.

## Verification

Cloud run: replay, clock skew and nonce store failover cases in the load test plan.

## Reopen when

The load test shows the gateway hop above its 7 ms allocation at the 1500 rps plateau, or a replay passes the durable IDs.
