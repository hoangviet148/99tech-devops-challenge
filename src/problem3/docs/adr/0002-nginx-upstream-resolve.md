# ADR-P3-0002: nginx 1.30 with an upstream that re-resolves Docker DNS

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-2, REQ-P3-3, REQ-P3-5 |
| Principles | REL-DP1, REL-DP3 |
| Supersedes | none |

## Context

nginx proxies to port 3001 while the API listens on 3000 (F1). It also resolves `api` once at startup: after the API container was recreated on a new IP, nginx kept the old one and returned 502 until it restarted, or stalled about 14 s per request when the old IP was unassigned (F5). nginx 1.25 is past its end of life (2024-05-29).

## Decision

nginx moves to 1.30 and proxies through `upstream api_upstream` with a shared `zone`, `server api:3000 resolve`, Docker's resolver at `127.0.0.11` with `valid=5s`, upstream keepalive, a 2 s connect and 10 s read timeout, and `proxy_next_upstream error timeout` limited to 2 tries.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Hostname in a `proxy_pass` variable with a resolver | Works on nginx 1.25 | Resolution per request outside any upstream, so no keepalive pool, no shared peer state, no passive health | Fixes F5 at the price of connection reuse and failover |
| Reload nginx whenever the API changes | No config change | Couples every API recreate to an nginx action, the gap is an outage | Turns a routine recreate into an operational step |
| Replace nginx with Traefik, HAProxy or Envoy | Dynamic discovery, active health checks | A new component and configuration language for a one-line defect | Larger change than the problem, and HAProxy needs the same resolver setup |
| Docker DNS round robin without an upstream block | Simplest | No keepalive, no passive health, still resolved once | Keeps F5 |

## Trade-offs

The fix bundles a five-minor-version nginx upgrade with a behaviour change, which widens the blast radius of one commit (OPS-DP4). `nginx -t` on 1.30.6 and scenarios S1, S6 and S8 bound that risk. Retries apply only before a response starts reaching the client, and nginx does not resend a non-idempotent request that already reached a peer, so the retry adds no duplicate writes.

## Consequences

### Positive

- An API recreate no longer needs an nginx restart (F5).
- A dead replica is skipped after one failed attempt for 5 s (`max_fails=1 fail_timeout=5s`).

### Negative

- Open-source nginx has passive health checks only, so a replica that accepts connections but answers slowly stays in rotation until it times out.

### Risks

- DNS answers can lag a recreate by up to the 5 s TTL. S6 allows 15 s and measures the real delay.

## Verification

S1, S6 and S8 in `scripts/verify.sh` (local run), and `nginx -t` on the pinned image (local run).

## Reopen when

Active health checks become a requirement, or the API moves behind a cloud load balancer that owns discovery.
