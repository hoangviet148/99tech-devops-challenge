# ADR-P3-0009: Two API replicas and an internal backend network

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-2, REQ-P3-5 |
| Principles | REL-DP3, SEC-DP3 |
| Supersedes | none |

## Context

The template runs one API container, so any crash or restart of it is an outage. All four services share one flat network, which lets nginx reach Postgres and Redis directly although it only needs the API.

## Decision

The API runs two replicas by default. nginx and the API share an `edge` network, and the API, Postgres and Redis share a `backend` network marked `internal: true`, so the data stores have no route out and no path from nginx.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| One replica | Half the memory | A crash or a deploy is an outage | Fails the "sometimes inaccessible" report at its root |
| Three or more replicas | More headroom | Each replica costs 5 Postgres connections from a budget of 25 | Two survive a single failure, which is the requirement here |
| One flat network with host firewall rules | No compose change | Rules live outside the compose file and do not travel with it | Not reviewable alongside the stack |

## Trade-offs

Memory use doubles for the API. The internal network also blocks outbound internet for Postgres and Redis, which neither needs.

## Consequences

### Positive

- A replica can crash, restart or be recreated while the other serves (S6, S8, S9).
- nginx can no longer reach the data stores.

### Negative

- Two replicas share one database, so a database fault still affects both.

### Risks

- Port publishing does not work on an internal network, so test tooling that needs a host port, such as Toxiproxy, also joins the edge network.

## Verification

S8 and S9 in `scripts/verify.sh` and `docker network inspect` on both networks (local run).

## Reopen when

The stack moves to an orchestrator with network policies and replica autoscaling.
