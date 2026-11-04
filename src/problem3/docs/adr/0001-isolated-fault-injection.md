# ADR-P3-0001: Diagnose by isolated fault injection and fix one root cause per commit

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-1, REQ-P3-3, REQ-P3-4 |
| Principles | REL-DP2, GEN-DP6, OPS-DP6 |
| Supersedes | none |

## Context

The README reports an API that is "unreliable and sometimes inaccessible" and ships no logs, metrics or traces. A healthy-path load test passes once the port is fixed (F0: p99 44 ms at 50 concurrent requests), so the failures appear only when a dependency changes state. Reading the code finds candidate defects, but it cannot rank them, cannot show the stale DNS of F5, and cannot prove that a fix works.

## Decision

Each symptom is reproduced by changing one dependency at a time under steady load (restart, pause, stop, recreate, scale), each hypothesis is confirmed with the smallest probe change, and every root cause lands in its own commit together with the scenarios it turns green.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Static code review only | Fast, finds F1, F3 and F12 from source | Cannot reproduce F2, F5 or F7, cannot prove a fix | REQ-P3-3 asks for root causes, and a root cause needs a reproduction |
| Rewrite the stack, then test | Less incremental work | Loses causality: no way to tell which change fixed which symptom | A reviewer could not follow the diagnosis |
| Chaos tooling such as Pumba or Chaos Mesh | More fault types | Pumba needs the Docker socket, Chaos Mesh needs Kubernetes | The Docker CLI already covers restart, pause, stop and recreate |

## Trade-offs

The commit series is slower than one large change, since every commit runs the scenarios it touches. That cost buys a history in which each fix is tied to the evidence that motivated it.

## Consequences

### Positive

- Every finding F0 to F12 has a reproducible evidence row.
- A reviewer can bisect the series and watch one scenario turn green per commit.

### Negative

- The harness (ADR-P3-0011) becomes code to maintain.

### Risks

- Timing-dependent faults can produce flaky results. Repeated faults, recovery clocks from dependency readiness and explicit deadlines in ADR-P3-0011 mitigate that.

## Verification

Matched before and after tables from `scripts/verify.sh` (local run), with probe overrides and commands in `evidence/probes/`.

## Reopen when

The stack moves to an orchestrator that brings its own fault-injection tooling.
