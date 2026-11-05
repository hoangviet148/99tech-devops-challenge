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

Five problems, each with its own decision records, invite two failure modes: a decision that serves no requirement and exists because it looks good, and a requirement that no decision answers. Free-text justifications drift from the documents they describe, and nobody rereads every decision record by hand after each change. The problems also cite each other's IDs: Problem 1 relies on Problem 5 controls, and Problem 5 builds on Problem 1 decisions.

## Decision

`docs/requirements.md` and `docs/principles.md` are the only registers, every decision record cites IDs from both, every `SOLUTION.md` has a traceability section that names each of its requirements, and a `SOLUTION.md` that restates a requirement copies the register's words. `tools/trace_check.py` fails on an undefined or malformed requirement, principle or decision record ID, on a local ID that no ID table defines when it is hyphenated like SC-01 or belongs to a family of its own problem like S1 in Problem 3, and on a record without requirements, principles, the metadata, sections and consequence subsections of `template.md` or two alternatives. It also fails on a requirement that no record cites, that its traceability table leaves out or that a `SOLUTION.md` table headed `ID | Requirement` restates in other words, on a problem record that its own `SOLUTION.md` does not cite or a root record that the root README does not cite, on a principle set that `docs/principles.md` lists or omits against the records and the traceability table of a problem, and on a missing `SOLUTION.md`, assumptions section or traceability section.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Free-text reasons in each document | No tooling | Nothing catches a decision without a reason or a requirement without an answer | Drift goes unnoticed |
| A traceability spreadsheet | Familiar, sortable | Lives outside the repo, not reviewed with the change it describes | Cannot fail a check |
| One register per problem | Each problem self-contained | Principles repeat five times, and the same principle could carry different names | Loses the view across problems that a reviewer needs to follow one principle |

## Trade-offs

The script checks IDs and the fields and headings of the template, not judgement. A record can cite the right IDs for a weak reason, and the length of its Context and Decision, the principle its Trade-offs name and the kind of check its Verification names are left to the review round of ADR-0004, traded against the speed of a purely automatic gate (OPS-DP3).

## Consequences

### Positive

- A reviewer can follow one principle, such as REL-DP2, across all five problems.
- The check runs offline with the Python standard library.

### Negative

- A new requirement, principle or local ID needs a row in a table headed `ID` before the check passes, and a new decision record needs its file and its index row.
- A change of wording touches the register and every `SOLUTION.md` that restates the requirement.
- The row of a problem in `docs/principles.md` changes whenever its records or its traceability table start or stop citing a set.

### Risks

- An unhyphenated token such as S3 or EC2 counts as an ID only in a problem that defines that family, and a standard name such as SHA-256 or TLS-1.3 is not an ID unless a problem defines its family, so a citation of another problem's unhyphenated ID or a mistyped standard name goes unchecked. The script prints these tokens on the `not checked` line of each problem, so a reviewer sees what it skipped.

## Verification

`python3 -I tools/test_trace_check.py` breaks each rule once on a fixture tree, and `python3 -I tools/trace_check.py` passes on the merged `main` (offline test). The root workflow runs both (CI).

## Reopen when

The check fails on a correct tree, or passes on a tree where a reviewer finds an undefined ID or a requirement that no document answers.
