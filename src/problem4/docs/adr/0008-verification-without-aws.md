# ADR-P4-0008: Verification without AWS through a recording fake CLI and dry runs

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-4, REQ-P4-5 |
| Principles | REL-DP2, REL-DP5, OPS-DP3 |
| Supersedes | none |

## Context

There is no AWS account (A7, REQ-P4-5), yet the deploy scripts decide when to activate, when to roll back and when to stop. Branches of that logic that never run are where a pipeline fails during a real incident. The task accepts a faithful implementation of what cannot run, so the scripts have to be the real ones, with AWS replaced underneath them.

## Decision

Every AWS call in the scripts goes through `aws_call` in `scripts/lib.sh`. The tests put a fake `aws` and a fake `curl` first on `PATH`: the fake CLI stores objects under `FAKE_AWS_STATE`, logs every call to `FAKE_AWS_LOG`, honours conditional writes and fails a chosen step on request (`FAKE_AWS_FAIL`, `FAKE_TARGET_STATUSES`, `FAKE_TARGET_HEALTH`, `FAKE_INVALIDATION_WAIT`, `FAKE_DEPLOY_WAIT`), and the fake `curl` serves the fake bucket with CloudFront-like rewrites. With `--dry-run`, which the workflows pass unless `DEPLOY_ENABLED` is `true`, `aws_call` prints the call and returns an empty JSON object.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Stub each command inline in each test | No shared fake | Every test reimplements S3 behaviour, and conditional writes drift between tests | One fake keeps that behaviour in one place |
| LocalStack in CI | Real S3 API behaviour | A service container per run, and the CodeDeploy target statuses and ALB health the fleet check reads would still need stubs | Kept as a later addition for the S3 part only |
| Review without tests | No effort | Rollback paths stay unexercised until production | Fails REL-DP2 |

## Trade-offs

A fake can agree with the scripts and disagree with AWS. The fake returns only the fields the scripts read (`ChecksumSHA256`, `VersionId`, the `PreconditionFailed` error, deployment target statuses and target health states), and the AWS acceptance plan repeats the same scenarios against real services. Speed and repeatability on every pull request come at the price of fidelity, which "Test systems at production scale" (GEN-DP2) would not accept for production sign-off.

## Consequences

### Positive

- The failure paths run on every pull request: an upload failing midway, a failed waiter, a wrong checksum, a missing artifact, a failed last instance, a failed smoke test, a vetoed rollback and a rollback to a release that is gone.
- The disabled deployment path on GitHub runs the same scripts and makes no AWS call.
- The browser test drives the real deploy script against the fake bucket and serves that bucket to Playwright through a local server with the deep-link rewrite.

### Negative

- The fakes need an update whenever a script reads a new field.

### Risks

- A field the fake returns but AWS shapes differently would hide a bug. The AWS acceptance plan runs the same scenarios on AWS before the pipeline is trusted with production.

## Verification

`scripts/tests/run-all.sh` runs every suite in the delivery job, including `test_dry_run_makes_no_aws_call` in both deploy suites (offline test). The dry-run path of both CD workflows runs on the demo repository (GitHub demo).

## Reopen when

An AWS account becomes available for the acceptance plan, or a cloud run finds a behaviour the fake did not model.
