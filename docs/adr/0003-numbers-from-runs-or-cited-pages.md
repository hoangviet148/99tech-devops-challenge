# ADR-0003: Every number comes from a recorded run or a cited vendor page

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-G2, REQ-P3-3, REQ-P1-10 |
| Principles | GEN-DP5, OPS-DP7 |
| Supersedes | none |

## Context

A design document full of plausible numbers reads well and can be wrong in every line: a price from last year, a timeout from another library version, a latency nobody measured. A reviewer cannot tell a measured number from a guess unless the document says which is which (REQ-G2).

## Decision

Every number in a `SOLUTION.md` or a decision record comes from an `evidence/` file produced by a script in the repo, or from a vendor page or source file cited with the date it was read. A value that is not known yet is a named placeholder such as `<DR_REGION_PRICE>`, and prices carry the offer version and date of the AWS price list.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Typical values from experience | Fast to write | Unverifiable, and often outdated for fast-moving services and libraries | The reviewer cannot check them |
| No numbers at all | Nothing to be wrong | Capacity, alert thresholds and cost cannot be judged | The tasks ask for latency, scale and cost answers |
| Numbers with a confidence note | Honest about uncertainty | Still unverifiable, and the note gets dropped in copies | A placeholder makes the gap explicit |

## Trade-offs

Measuring before writing slows the work, and some facts stay as placeholders until an account or a vendor answer exists, traded against a document that reads complete (GEN-DP5).

## Consequences

### Positive

- Problem 3 shows before and after numbers from the same script on the same machine.
- The measurement for Problem 2 changed a claim: on a full disk NGINX kept answering while it dropped most access log lines, which the first draft had not predicted.

### Negative

- Results from a laptop Docker VM do not transfer one to one to production hardware, and each evidence file says where it ran.

### Risks

- A vendor page changes after the date it was read. The date next to each citation tells a reader when to recheck.

## Verification

Each `evidence/README.md` names the command behind every file, and the review round checks a sample of citations (review).

## Reopen when

A number in a `SOLUTION.md` has no evidence file or citation, or a cited page contradicts the document.
