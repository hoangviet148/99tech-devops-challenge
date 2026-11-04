# ADR-0002: One requirement register and one principle list, traced by a script

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-G2, REQ-G3 |
| Principles | OPS-DP3, SEC-DP2 |
| Supersedes | none |

## Context

Five problems with about 70 decisions invite two failure modes: a decision that serves no requirement and exists because it looks good, and a requirement that no decision answers. Free-text justifications drift from the documents they describe, and nobody rereads 66 decision records by hand after each change.

## Decision

`docs/requirements.md` and `docs/principles.md` are the only registers. Every decision record cites IDs from both, and every `SOLUTION.md` ends with a traceability table. `tools/trace_check.py` fails on an undefined ID, on a decision record without requirements, principles, two alternatives or a reopen trigger, on a record that no `SOLUTION.md` cites, on a requirement that no record cites, and on a missing `SOLUTION.md` or assumptions section.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Free-text reasons in each document | No tooling | Nothing catches a decision without a reason or a requirement without an answer | Drift goes unnoticed |
| A traceability spreadsheet | Familiar, sortable | Lives outside the repo, not reviewed with the change it describes | Cannot fail a check |
| One register per problem | Each problem self-contained | Principles repeat five times, and the same principle could carry different names | Loses the view across problems that a reviewer needs to follow one principle |

## Trade-offs

The script checks IDs and structure, not judgement. A record can cite the right IDs for a weak reason, so the review round of ADR-0004 stays necessary, traded against the speed of a purely automatic gate (OPS-DP3).

## Consequences

### Positive

- A reviewer can follow one principle, such as REL-DP2, across all five problems.
- The check runs offline in a second.

### Negative

- Every new ID needs a table row that defines it before the check passes.

### Risks

- The ID patterns of the script can miss a new ID family. The script prints every family it found, so a missing one shows in its output.

## Verification

`python3 -I tools/trace_check.py` on the merged `main` (offline test).

## Reopen when

The submission grows past what one register can hold, or a reviewer finds a requirement the check reported as covered that no document answers.
