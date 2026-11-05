# ADR-0005: Markdown with Mermaid as the only document format

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-G1, REQ-P1-9 |
| Principles | OPS-DP5, SEC-DP2 |
| Supersedes | none |

## Context

The reviewer must be able to read every solution without pain, which the instructions say includes unzipping (REQ-G1), and Problem 1 asks for an overview diagram of the services (REQ-P1-9). Documents that sit next to code drift unless a change to one shows up in the same diff as the other.

## Decision

Every document is Markdown, and every diagram is a Mermaid block inside it. Every file under `evidence/`, the run outputs and the scripts and probe inputs kept beside them, is plain text that a diff shows.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| PDF or Word documents | Rich layout | A download to read, no diff in review | Breaks REQ-G1 and hides changes |
| Diagrams as images from a drawing tool | Any layout | A binary file that no diff can show, and a source file next to it | Changes become invisible in review |
| A static documentation site | Navigation, search | Needs hosting or a local build | More pain than the GitHub web view |

## Trade-offs

Mermaid limits layout, so large diagrams are split into several small ones, traded against diagrams that change in the same diff as the text (OPS-DP5).

## Consequences

### Positive

- GitHub renders every document and diagram in the browser.

### Negative

- Complex diagrams such as the Problem 1 overview are less polished than a drawing tool would make them.

### Risks

- A Mermaid syntax error renders as an error box. The diagrams are parsed with Mermaid 11 before they are committed.

## Verification

Every `SOLUTION.md` opened in the GitHub web view before the link is shared (review).

## Reopen when

A reviewer cannot read a document in the GitHub web view, or a diagram cannot be expressed in Mermaid.
