# ADR-0004: Independent technical review before execution and before each merge

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-G2, REQ-G3 |
| Principles | OPS-DP6, OPS-DP7 |
| Supersedes | none |

## Context

The author of a design is the worst reviewer of its blind spots. Problems 1 and 5 can only be verified by review, since they have no AWS account to run against, and a flaw found after the code exists costs a rewrite. `docs/review-log.md` records what each round found.

## Decision

A second reviewer with read-only access to the repository reviewed the plan before any execution, round after round, until it returned "execute" with no open blocker. Each problem gets one more round before its branch merges into `main`, and a P0 or P1 finding blocks the merge until it is fixed or written down as an accepted trade-off.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Self-review only | Fast | Misses the blind spots of the author, which is where design errors live | The cheapest finding is the one made before the work |
| One review at the end | One round instead of several | Findings arrive when the rework is most expensive | Round 1 alone found 8 P0 problems in the plan |
| Peer review only of the code | Familiar | Problems 1 and 5 have no code to review | Leaves the design-only answers unreviewed |

## Trade-offs

Five rounds before execution delayed the first commit, traded against fewer rewrites later (OPS-DP6). Every finding was checked against the code or the vendor page it cites before it was accepted, so a wrong finding costs time too.

## Consequences

### Positive

- Contradictions between problems, such as a security control that breaks a latency budget, surface before both answers are written.

### Negative

- The review rounds add calendar time that a single author does not need.

### Risks

- A reviewer that shares the author's assumptions confirms them. Each round reads the documents fresh, and findings are checked against primary sources.

## Verification

`docs/review-log.md` lists each round with its verdict and finding counts (review).

## Reopen when

A merged problem turns out to contain a P0 or P1 problem that a round should have caught.
