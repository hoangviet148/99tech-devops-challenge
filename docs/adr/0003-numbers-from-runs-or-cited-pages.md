# ADR-0003: Every measured or priced number comes from a recorded run or a cited page

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-G2, REQ-P3-3, REQ-P1-10 |
| Principles | GEN-DP5, OPS-DP7 |
| Supersedes | none |

## Context

A design document full of plausible numbers reads well and can be wrong in every line: a price from last year, a timeout from another library version, a latency nobody measured. A reviewer cannot tell a measured number from a guess unless the document says which is which (REQ-G2). The answers also need numbers that no run or vendor page can give, such as an availability objective or an alert threshold, because the design chooses them.

## Decision

A measured or priced number in a `SOLUTION.md` or a decision record, such as a latency, a size, a price or a product limit, comes from an `evidence/` file produced by a script in the repository, from a command that an `evidence/` README records with its observed output and date, such as the diagnosis probes of Problem 3, or from a vendor page or source file cited with the date it was read. Targets, thresholds, allocations and sizing quantities are design values of this submission, and those that rest on an assumption appear in the problem's assumptions section or in a requirement whose ID ends in `A`. A fact that is not known yet is a named placeholder such as `<DR_REGION_PRICE>`, and prices carry the offer version and the date of the AWS price list.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Typical values from experience | Fast to write | Unverifiable, and often outdated for fast-moving services and libraries | The reviewer cannot check them |
| No numbers at all | Nothing to be wrong | Capacity, alert thresholds and cost cannot be judged | The tasks ask for latency, scale and cost answers |
| Guessed facts with a confidence note | Honest about uncertainty | Still unverifiable, and the note gets dropped in copies | A placeholder makes the gap explicit |

## Trade-offs

Measuring before writing slows the work, and some facts stay as placeholders until an account or a vendor answer exists, traded against a document that reads complete (GEN-DP5).

## Consequences

### Positive

- Problem 3 shows before and after numbers from the same script, and every verify file records the Docker version it ran on.
- The measurement for Problem 2 changed a claim: on a full disk NGINX kept answering while it dropped most access log lines, which the first draft had not predicted.

### Negative

- Results from the local runs do not transfer one to one to production hardware, and the root README names the runtime that the run outputs record.

### Risks

- A vendor page changes after the date it was read. The date next to each citation tells a reader when to recheck.

## Verification

The run table of the root README names the script behind each kind of run output. `src/problem3/evidence/probes/README.md` gives the commands and the observed output behind the diagnosis findings, and `src/problem4/evidence/README.md` gives the command behind each captured output. The review round checks a sample of the numbers against these sources (review).

## Reopen when

A measured or priced number in a `SOLUTION.md` or a decision record has no evidence file or citation, or a cited page contradicts the document.
