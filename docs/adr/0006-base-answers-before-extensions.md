# ADR-0006: Base answers for all five problems before any extension

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-G3 |
| Principles | OPS-DP4, GEN-DP4 |
| Supersedes | none |

## Context

The instructions say every problem should at least be attempted (REQ-G3). The Notion page budgets 34 hours for the four problems that state a time, and gives none for Problem 5. Extensions such as Terraform for Problem 4 or a live GitHub demonstration could absorb the time of a whole problem.

## Decision

Phase A delivers a complete and verified answer for every problem before Phase B starts any extension. The extensions are monitoring for Problem 3, Terraform and a GitHub demonstration for Problem 4, and LocalStack runs, each started only after the five base answers exist.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Depth first, one problem at a time with all its extensions | The best single answer | Later problems risk getting no answer | Breaks REQ-G3 under time pressure |
| Breadth only, no extensions | Simplest plan | Gives up the checks that make Problems 3 and 4 convincing | The monitoring of Problem 3 was cheap once the base answer existed |

## Trade-offs

An extension waits even when it would be cheap to do while the context is fresh, traded against a complete submission at every point in time (OPS-DP4).

## Consequences

### Positive

- At any point after Phase A the submission answers all five problems.

### Negative

- Some extensions, such as the GitHub demonstration, need a decision from the owner and may not happen at all.

### Risks

- A base answer that looks complete can hide a gap that only an extension would expose. The review round of ADR-0004 checks each base answer against its requirements.

## Verification

`tools/trace_check.py` fails when one of the five `SOLUTION.md` files is missing (offline test).

## Reopen when

The time budget changes, or a reviewer values one deep answer over five complete ones.
