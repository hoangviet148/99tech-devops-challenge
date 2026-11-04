# ADR-P4-0005: Build once into immutable artifacts with a release manifest

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-1, REQ-P4-2, REQ-P4-4, REQ-P4-5 |
| Principles | OPS-DP3, OPS-DP4, REL-DP5, SEC-DP2, FSI-DP2, FSI-DP4 |
| Supersedes | none |

## Context

A build per environment can put other bytes into production than the ones staging ran. Promotion needs evidence that production deploys exactly what staging verified, and the job that benefits from that evidence must not be able to write it. Without an AWS account (REQ-P4-5) the same path still has to run end to end.

## Decision

Only the build jobs of `backend-cd.yml` and `frontend-cd.yml` build. Each writes `<app>-<sha>.tgz` with its SHA-256, a build record and an SBOM, attests provenance, uploads the files as the GitHub artifact `<app>-<sha>` and publishes the tarball and the record to S3 with conditional writes. The build record lands under `builds/` of a manifest bucket and every deploy or rollback appends one under `staging/` or `production/`, each prefix writable by one role, and production requires the attestation and a staging deploy record with the same digest.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Build inside each deploy job | No artifact store | Other bytes per environment, and a toolchain change goes untested between staging and production | Breaks the promotion evidence |
| A container registry with image digests | Digest addressing built in | The backend runs under systemd and the frontend as static files, so images would only wrap tarballs | Adds a registry without changing what runs |
| GitHub artifacts as the only store | No S3 bucket for builds | CodeDeploy reads the revision from S3 here, and the GitHub copy expires after the 30 days this repository sets | Rollback needs artifacts that outlive that retention |
| Deploy records in a DynamoDB table | Queries and conditional writes | A second data store and another IAM surface | S3 conditional writes give the same append-only property |

## Trade-offs

Records are append-only, so a wrong record stays and a newer one corrects it, which favors traceability (SEC-DP2) over convenient edits. The production gate needs a staging record, so a hotfix cannot skip staging, which lengthens the path for urgent changes (OPS-DP4) by design.

## Consequences

### Positive

- Production receives the SHA-256 that staging ran. Before any deploy step it checks the S3 object checksum, the build record under `builds/` (digest, and for the backend the S3 object version) and a staging record with the same digest.
- The build record names the S3 object version, which `publish-artifact.sh` reads after the upload. A rerun of the build for the same commit accepts an existing record when its digest and version match, so it never conflicts.
- A rebuild of the same commit gives the same digest (ADR-P4-0013), so the publish step of a rerun is a no-op.
- With `--dry-run`, which the workflows pass unless `DEPLOY_ENABLED` is `true`, every AWS call is printed instead of made.

### Negative

- Production makes three reads before it changes anything (object head, build record, staging record), and each one is a place a misconfigured bucket policy shows up as a refused deploy.
- The build record is written after the artifact, so a publish that fails between the two leaves an artifact without a record, and production refuses it until a rerun writes the record.

### Risks

- The staging deploy role writes the records production trusts, so a compromised role could forge one. That role is reachable only from the staging environment through the reusable deploy workflow on `main` (ADR-P4-0006), and production also verifies the attestation.
- Nothing in the pipeline deletes artifacts or records. The retention rules in `SOLUTION.md` section 7 belong to a cleanup job with its own role, which is left out, so storage grows until that job exists.

## Verification

Both deploy suites in `scripts/tests/` check that production without a matching staging record or with a build record of another digest is refused, that a wrong checksum never deploys and that a dry run makes no AWS call. `scripts/tests/test-publish-artifact.sh` checks the recorded object version and the rerun of a build (offline test). `infra/policies/test_policies.py` checks one writer per manifest prefix and the denial of deletes and unconditional writes (offline test). `scripts/verify-provenance.sh` runs in the deploy jobs of the demo repository (GitHub demo).

## Reopen when

Promotion needs more than two environments, or a question about releases needs a query that listing one prefix cannot answer.
