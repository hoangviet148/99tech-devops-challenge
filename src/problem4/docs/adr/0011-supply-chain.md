# ADR-P4-0011: Supply chain: pinned actions, attestations, SBOM, workflow linters

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-3, REQ-P4-4 |
| Principles | SEC-DP2, SEC-DP3, SEC-DP4 |
| Supersedes | none |

## Context

The pipelines run third-party actions inside jobs that can request OIDC tokens, and the artifacts they produce are promoted to production. A version tag of an action can move to other code under the same name, a dependency can arrive with a known vulnerability, and without provenance nobody can prove which workflow built the bytes that run.

## Decision

Actions are pinned by commit SHA, workflows start from `permissions: {}` with grants per job, checkouts set `persist-credentials: false`, and expressions reach `run:` scripts only through `env:`. Build jobs attest provenance and write an SPDX SBOM, and before any deploy step `scripts/verify-provenance.sh` requires an attestation from the app's CD workflow on `refs/heads/main`, built on a GitHub-hosted runner. CI runs `actionlint`, `zizmor`, `shellcheck`, `gitleaks`, `trivy fs`, `npm audit --audit-level=high` and dependency review, with scanner images pinned by digest and Dependabot proposing action and npm updates weekly, each version at least 7 days old.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Pin actions by version tag | Readable references | A tag can move to other code | A moved tag runs unreviewed code with the job's permissions |
| Vendor every action into the repository | Full control of the code | Copies to maintain and update by hand | SHA pins plus Dependabot give review without the copies |
| Sign artifacts with a self-managed key, for example cosign with KMS | Works on private repositories | A key to protect and rotate | Attestations use the workflow's OIDC identity and need no key |
| Scan on a schedule only | Fewer CI minutes | A vulnerable dependency merges before the scan finds it | The pull request is where the fix is cheapest |

## Trade-offs

GitHub's documentation on artifact attestations states that private repositories need GitHub Enterprise Cloud, so verification runs on the public demo repository only. The decision accepts that dependency on a GitHub feature for traceability (SEC-DP2) instead of a signing key to protect. `zizmor` runs its online audits with the job's read-only token, so a third-party container sees that token for the length of the job (SEC-DP3).

## Consequences

### Positive

- A deploy job refuses an artifact that the CD workflow on `main` did not build.
- A changed action, a new dependency or a leaked secret shows up in the pull request that introduces it.

### Negative

- SHA pins are unreadable without the version comment, and every update arrives as a pull request to review.
- The scanner images in `lint-workflows.sh` and `scan.sh` and the build image in `build-backend.sh` sit outside Dependabot's reach and need manual bumps.

### Risks

- An attestation proves which workflow built the bytes, not that a person reviewed the source. The ruleset on `main` with code owner review (G1) covers review.

## Verification

`scripts/lint-workflows.sh` and `scripts/scan.sh` run in the `workflow-lint` and `security` jobs of `ci.yml` (offline test). `scripts/tests/test-verify-provenance.sh` feeds attestations from an unapproved workflow, another branch and a self-hosted runner through a fake `gh` (offline test). Attestation creation and verification against GitHub run on the demo repository (GitHub demo).

## Reopen when

A vulnerable action or dependency reaches `main` despite these checks, or the submission needs attestations on a private repository.
