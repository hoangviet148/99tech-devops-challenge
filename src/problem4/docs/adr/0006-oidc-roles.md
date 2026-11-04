# ADR-P4-0006: One OIDC role per app and environment, subject pinned to the reusable workflow

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-4, REQ-P4-5 |
| Principles | SEC-DP1, SEC-DP6 |
| Supersedes | none |

## Context

Build and deploy jobs need AWS credentials. Access keys stored as repository secrets live for months, and any workflow that references the secret can read it. With GitHub OIDC the trust policy decides which job may assume a role, but a subject that names only the repository and the environment admits any workflow that uses that environment. Repositories created after 2026-07-15 get subjects with immutable owner and repository IDs.

## Decision

Each app has one build role and one deploy role per environment, six roles in `infra/policies/trust/`. Each trust policy requires `aud` equal to `sts.amazonaws.com` and an exact `sub` with the immutable repository IDs, the environment (or `refs/heads/main` for a build) and the `job_workflow_ref` of one workflow on `main`. Before the credential step, `scripts/oidc-claims.sh` prints the token's claims without the token and fails on another `aud` or on a `sub` that differs from `OIDC_EXPECTED_SUB`.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Access keys in repository secrets | No federation setup | Long-lived keys, readable by any workflow that references them | Violates G7 |
| One deploy role per environment for both apps | Half the deploy roles | The frontend job could deploy the backend and the other way round | A role reachable from the wrong job |
| Subject with the environment only | No repository setting to change | Any workflow on `main` that names the environment can assume the role | Wider than one reusable workflow |
| Wildcard subjects such as `repo:OWNER/REPO:*` | Simple | Any branch, tag or pull request job matches | The reach G7 removes |

## Trade-offs

Pinning the immutable IDs and `job_workflow_ref` ties each trust policy to one repository and one workflow path. Renaming a workflow file or moving to a new demo repository means updating six trust policies and the expected subjects, which gives up agility (OPS-DP4) for a strong identity boundary (SEC-DP1).

## Consequences

### Positive

- No AWS secret exists in GitHub, and credentials last for one job.
- A rollback from `rollback.yml` runs the same reusable deploy workflow, so it assumes the same role under the same subject as a deploy.

### Negative

- The OIDC subject template is a repository setting outside the code, documented in `SOLUTION.md`.
- With `OIDC_EXPECTED_SUB` empty, `oidc-claims.sh` prints the claims and passes only while the job makes no AWS call, so a first dry run can capture the value. Once `DEPLOY_ENABLED` is `true` the workflows pass `--require-sub` and an unpinned subject fails the job. STS enforces the exact `sub` of the trust policy either way.

### Risks

- A wrong subject template makes STS refuse every deploy. The claims dump shows the actual `sub` in the job log before the credential step.

## Verification

`infra/policies/test_policies.py` fails on a missing trust policy, a shared subject, a wildcard, a missing audience, or a subject that does not pin the environment and the workflow (offline test). `scripts/tests/test-oidc-claims.sh` checks the claim assertion, the unpinned subject with and without `--require-sub`, and the masking of the token against a fake token endpoint (offline test). The claims dump runs on the demo repository (GitHub demo). STS denials for the wrong app, environment, audience and ref belong to the AWS acceptance plan (cloud run).

## Reopen when

GitHub changes the subject format again, or a deploy needs a role in an account outside the two environment accounts.
