# ADR-P3-0011: Failure-injection harness in bash with k6 and Toxiproxy

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-1, REQ-P3-3, REQ-P3-4 |
| Principles | REL-DP2, GEN-DP2, GEN-DP6 |
| Supersedes | none |

## Context

ADR-P3-0001 needs faults that repeat exactly, timing measured per request, and a before and after comparison on matched topology. A reviewer should be able to rerun it with Docker and a few common tools. Closed-loop load generators such as `ab` slow down when the server slows down, so they hide latency under faults.

## Decision

`scripts/verify.sh` is a bash orchestrator, compatible with bash 3.2, that recreates the stack for each scenario, drives load with k6 at a constant arrival rate in a pinned container, blackholes Redis through Toxiproxy, and reads per-request timestamps and statuses from the k6 JSON output. `scripts/verify-before.sh` runs the same scenarios on a worktree of `upstream/main` with the probe overrides.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Python with pytest | Richer assertions, easier maintenance | A Python environment and packages for every reviewer | Adds setup that Docker plus bash avoids |
| `ab` or `hey` for load | Already installed | Closed loop, no per-request timestamps, hides latency during faults | Cannot measure recovery windows |
| Pumba or Chaos Mesh | More fault types | Docker socket access or a Kubernetes cluster | Heavier than the faults this stack needs |
| A manual runbook | Nothing to build | Not repeatable, no before and after comparison | Fails REQ-P3-3 on proof |

## Trade-offs

Logic in bash with `awk` and `jq` is harder to maintain than Python, and a full run takes about 20 minutes. The script stays under one file with one function per scenario to keep it readable.

## Consequences

### Positive

- Every claim in `SOLUTION.md` points to a scenario that a reviewer can rerun.
- The same script measures the template and the fix, so the comparison is matched.

### Negative

- Docker Desktop timing on a laptop differs from a server. Criteria use margins and repeated faults for that reason.

### Risks

- Editing the script while a run is in progress breaks that run, because bash reads scripts as it executes. Runs happen from a clean tree.

## Verification

`shellcheck -s bash` (offline test) and both profiles executed end to end with results in `evidence/` (local run).

## Reopen when

The harness grows past about 20 scenarios or needs statistics that `awk` cannot express readably, at which point it moves to Python.
