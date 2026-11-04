# ADR-P3-0005: Crash-only process with a restart policy and a bounded shutdown

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-2, REQ-P3-3 |
| Principles | REL-DP1, OPS-DP6 |
| Supersedes | none |

## Context

After the crash of F2 the API stayed down, because the compose file has no restart policy (F4). Node ran as PID 1 without a SIGTERM handler, so every `docker stop` waited 10 s and ended in SIGKILL with exit code 137 (F9). Docker Compose never restarts a container that turns unhealthy, so liveness has to come from the process exiting.

## Decision

A fatal error (`uncaughtException`, `unhandledRejection`) logs and exits 1, `restart: unless-stopped` brings the container back, and `init: true` forwards signals. SIGTERM starts a hard-stop timer of 8 s, closes the listener at once, drains in-flight requests for up to 5 s, ends the database pools within 2 s and Redis within 1 s, then exits 0.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Catch every error and keep running | No restart | The process continues in an unknown state, leaks stay hidden | Makes the next failure harder to diagnose |
| PM2 or another supervisor inside the container | Restarts in-process | Two supervisors, a new dependency | Docker already restarts the container |
| An autoheal sidecar that restarts unhealthy containers | Uses the healthchecks for liveness | Needs the Docker socket, which is root on the host | Security cost above the benefit |
| `restart: always` | Same behaviour at runtime | Also restarts a container an operator stopped on purpose once the daemon restarts | Fights deliberate operator actions |

## Trade-offs

Requests in flight on a crashing replica fail. S8 tolerates an error rate under 0.5 % in the 10 s after a kill, because nginx retries only requests that have not started a response.

## Consequences

### Positive

- A crashed replica returns without a person in the loop.
- `docker stop` completes within seconds and lets in-flight requests finish.

### Negative

- A crash loop restarts quickly. Docker's restart backoff doubles the delay between attempts, which limits load on Postgres.

### Risks

- The 8 s hard stop can cut a drain short during a dependency stall. S9 measures the stall case explicitly.

## Verification

S8 and S9 in `scripts/verify.sh` (local run).

## Reopen when

The stack moves to an orchestrator with liveness probes, which replaces the restart policy.
