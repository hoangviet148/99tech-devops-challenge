# ADR-0004: Independent technical review before each merge

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-G2, REQ-G3 |
| Principles | OPS-DP6, OPS-DP7 |
| Supersedes | none |

## Context

The author of a design is the worst reviewer of its blind spots. Problems 1 and 5 can only be verified by review, since they have no AWS account to run against, and Problem 5 builds on the Problem 1 design, so a flaw that reaches `main` in one answer spreads into the other. `docs/review-log.md` records what each round found.

## Decision

Each branch, the root documents included, gets a review round before it merges into `main`, by a second reviewer with read-only access to the repository. A P0 or P1 finding blocks the merge until it is fixed or written down as an accepted trade-off.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Self-review only | Fast | Misses the blind spots of the author, which is where design errors live | The cheapest finding is the one made before the merge |
| One review of the whole submission at the end | One round instead of several | Findings arrive when every answer that builds on a flawed one has to change too | Problem 5 builds on Problem 1, so a late finding in Problem 1 reopens both |
| Peer review only of the code | Familiar | Problems 1 and 5 have no code to review | Leaves the design-only answers unreviewed |

## Trade-offs

A round before each merge delays the merge, traded against fewer rewrites after it (OPS-DP6). Every finding is checked against the code or the vendor page it cites before it is accepted, so a wrong finding costs time too.

## Consequences

### Positive

- Contradictions between problems, such as a security control that breaks a latency budget, surface before the answers reach `main`.

### Negative

- The review rounds add calendar time that a single author does not need.

### Risks

- A reviewer that shares the author's assumptions confirms them. Each round reads the documents fresh, and findings are checked against primary sources.

## Verification

`docs/review-log.md` gives the verdict and the findings of the round before each merge (review).

## Reopen when

A merged branch turns out to contain a P0 or P1 problem that its round should have caught.
