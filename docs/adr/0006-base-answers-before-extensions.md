# ADR-0006: Base answers for all five problems before the remaining extensions

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-G3 |
| Principles | OPS-DP4, GEN-DP4 |
| Supersedes | none |

## Context

The instructions say every problem should at least be attempted (REQ-G3). The Notion page budgets 34 hours for the four problems that state a time, and gives none for Problem 5. Extensions such as Terraform for Problem 4 or a live GitHub demonstration could absorb the time of a whole problem. The commit history records the order of the work: `230c3af` added the Problem 3 monitoring right after `c031a5f` recorded the verify runs of the Problem 3 fixes, it is the parent of `88ed202`, which added the Problem 3 `SOLUTION.md`, and every commit that the branches of Problems 1, 2, 4 and 5 add to the template is later.

## Decision

Every problem gets a base answer before an extension starts: its `SOLUTION.md` and decision records committed, with the recorded runs that check them where the problem has runs. The one exception is the Problem 3 monitoring of ADR-P3-0012, committed on 2026-11-04 at 23:48 +0700 before the Problem 3 `SOLUTION.md` and before any commit of Problems 1, 2, 4 and 5, and now part of the Problem 3 answer to REQ-P3-4. The rule still holds for the other extensions, Terraform and the GitHub demonstration of Problem 4 and LocalStack runs: each starts after all five base answers are committed, and it merges only once the base answer of its problem has no open P0 or P1 finding (ADR-0004).

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Depth first, one problem at a time with all its extensions | The best single answer | Later problems risk getting no answer | Breaks REQ-G3 under time pressure |
| Breadth only, no extensions | The simplest order of work | Gives up the checks that make Problems 3 and 4 convincing | The Problem 3 monitoring was cheap once its fixes were verified |
| An extension whenever its problem's context is fresh | No context to rebuild later | Each extension delays the base answers that are still open | Kept only for the Problem 3 monitoring, whose stack and failure-injection harness were already running |

## Trade-offs

An extension waits even when its context is fresh, traded against small steps that give every problem an answer before any problem gets more (OPS-DP4). The Problem 3 monitoring is the recorded exception: it went ahead while its stack and failure-injection harness were running, and every commit that the branches of Problems 1, 2, 4 and 5 add to the template came after it. An open review finding on a base answer holds back the merge of an extension and not its start, since REQ-G3 is met once the five base answers exist and ADR-0004 keeps a branch with an open P0 or P1 finding out of `main`.

## Consequences

### Positive

- From the point where all five base answers existed, the submission has answered every problem.

### Negative

- Some extensions, such as the GitHub demonstration, need a decision from the owner and may not happen at all.
- The Problem 3 answer to REQ-P3-4 rests on its monitoring extension.

### Risks

- A base answer that looks complete can hide a gap that only an extension would expose. The review round of ADR-0004 checks each base answer against its requirements.

## Verification

`tools/trace_check.py` fails when a `SOLUTION.md` is missing (offline test). The commit history that the merge commits keep shows the order of the work, and `docs/review-log.md` gives the outcome of the round before each merge (review).

## Reopen when

An extension merges while the base answer of its problem has an open P0 or P1 finding, or the Notion time budget changes.
