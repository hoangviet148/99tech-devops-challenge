# ADR-P4-0002: Workflows stay under `src/problem4`, live runs use a subtree split

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-3, REQ-P4-6, REQ-G4 |
| Principles | OPS-DP3, SEC-DP2 |
| Supersedes | none |

## Context

The template places Problem 4 in `src/problem4`, and the submission keeps one folder per problem in one repository created from the template, never a fork (REQ-G4, ADR-0001). GitHub runs workflows only from `.github/workflows` at the repository root, so the files in `src/problem4/.github/workflows` never run in the submission repository. The pipelines still need live runs on GitHub for the demonstration in `SOLUTION.md`, and their OIDC subjects name exactly one repository.

## Decision

The workflows stay in `src/problem4/.github/workflows`, every path inside them is relative to `src/problem4`, and the reusable deploy workflows are called by local reference (`./.github/workflows/_deploy-backend.yml`). Live runs happen in a separate demo repository published with `git subtree split --prefix src/problem4`, where the same files sit at the root.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Move the workflows to the repository root with `working-directory: src/problem4` | Runs in the submission repository | Every path filter, artifact path and reusable workflow reference carries the prefix, and the root pipelines also run for changes to the other four problems | Couples the product to the layout of the submission |
| Keep Problem 4 in its own repository from the start | Simplest for GitHub | The submission spreads over several repositories, and a reviewer has to open each one (REQ-G1) | Breaks the one-repository layout of ADR-0001 |
| Copy the folder into a demo repository by hand | No git tooling | The copy drifts from the reviewed source, and nothing ties a demo commit to a source commit | Loses traceability (SEC-DP2) |

## Trade-offs

Split commits get new SHAs, so the SHA a demo run builds and deploys differs from the SHA of the same change in the submission repository. The build record stores the split SHA only, and `SOLUTION.md` keeps the table that maps each source SHA to its split SHA. That table is a manual step per published split, which OPS-DP3 would rather automate.

## Consequences

### Positive

- The product folder runs unchanged as the root of its own repository.
- The files reviewed in the submission and the files that ran on GitHub are the same bytes, since `git subtree split` rebuilds the split history from the source history.

### Negative

- A change reaches GitHub Actions only after a new split is pushed to the demo repository.
- The trust policies in `infra/policies/trust/` pin the demo repository's owner and repository IDs, so they are filled in again for any new demo repository.

### Risks

- The demo repository drifts if someone commits there directly. It receives split pushes only, and the table in `SOLUTION.md` lists each one.

## Verification

Running `git subtree split --prefix src/problem4` twice on the same source commit returns the same split SHA (local run). The GitHub demonstration in `SOLUTION.md` runs the split repository without AWS (GitHub demo).

## Reopen when

The submission moves to one repository per problem, or GitHub runs workflows from a subdirectory.
