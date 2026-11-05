# ADR-0001: One repository with a folder per problem, created from the template and never forked

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-G1, REQ-G4 |
| Principles | OPS-DP4, SEC-DP2 |
| Supersedes | none |

## Context

The template README warns that a fork links the answers publicly to the template, and the instructions ask that a reviewer can open every solution without pain (REQ-G1, REQ-G4). The Notion titles and the repo folders do not line up one to one: the README inside `src/problem3` is titled "Problem 4". GitHub runs workflows only from `.github/workflows` at a repository root, while the template asks for the Problem 4 workflows inside `src/problem4`.

## Decision

The submission is a new repository made from a clone of the template, with the template's history and folder layout, and never a GitHub fork. The repo folder is the identifier of each problem, every problem is built on its own branch and merged into `main`, and the root README maps the Notion titles to the folders.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| A GitHub fork of the template | One click, a visible link to the source | The answers become publicly linked to the template, which its README forbids | Breaks REQ-G4 |
| One repository per problem | Each problem stands alone, and Problem 4 workflows run at the root | Five links to share, and the shared registers and decision records repeat five times | More pain for the reviewer than one index (REQ-G1) |
| A zip archive attached to the application | Private by default | The instructions count unzipping as pain | Breaks REQ-G1 |

## Trade-offs

Problem 4 cannot run its workflows from this repository. Live runs use `git subtree split --prefix src/problem4` into a repository of their own (ADR-P4-0002), which gives the split commits new SHAs and costs a mapping table, traded against traceability (SEC-DP2).

## Consequences

### Positive

- One link opens all five answers, the registers and the decision records.
- The template's last commit `d514e60` stays in the history, so the template can be restored and the Problem 3 before runs can check it out from any full clone (OPS-DP4).

### Negative

- The Problem 4 demonstration needs a second, split repository.

### Risks

- A tool could create the remote as a fork by mistake. The root workflow fails on a fork, and the check under Verification runs before the link is shared.

## Verification

`url="$(git remote get-url origin)" && gh repo view "$url" --json isFork --jq .isFork` prints `false` for the published repository (local run, before the link is shared). The root workflow fails when the event payload marks the repository as a fork (CI). The root README index links every `SOLUTION.md` (review).

GitHub's webhook reference, https://docs.github.com/en/webhooks/webhook-events-and-payloads, marks `repository` as required in the `push`, `pull_request` and `workflow_dispatch` payloads. GitHub's OpenAPI description of the same payloads, `descriptions/api.github.com/api.github.com.json` in https://github.com/github/rest-api-description, requires the boolean `fork` in that object. Both were read on 2026-11-05.

## Reopen when

A reviewer asks for one repository per problem, or the template changes its folder layout.
