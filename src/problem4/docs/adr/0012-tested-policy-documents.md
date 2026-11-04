# ADR-P4-0012: IAM and bucket policies as tested documents before Terraform

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-4, REQ-P4-5 |
| Principles | SEC-DP1, SEC-DP4, OPS-DP3 |
| Supersedes | none |

## Context

The security of the pipelines rests on trust policies, role permissions and bucket policies (G4, G7). Without an AWS account none of them can be applied (REQ-P4-5), yet their mistakes cost the most: a wildcard subject, a deploy role that can write artifacts, a manifest prefix with two writers. The Terraform for the surrounding infrastructure is minimal, validated and never applied, and arrives after the pipelines.

## Decision

The policies live as JSON documents in `infra/policies/` (`trust/`, `permissions/`, `buckets/`, `endpoints/`), with placeholders such as `<PRODUCTION_ACCOUNT_ID>` for values only an account provides. `infra/policies/test_policies.py` checks their security properties with the Python standard library. The Terraform in `infra/terraform/` loads these files instead of restating the policies, and `scripts/terraform-check.sh` requires every policy in its offline plans to equal the document rendered with the variables of that plan.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Write the policies directly in Terraform | One source | The properties hide inside HCL, and checking them needs a plan with providers configured | Harder to test without an account |
| IAM Access Analyzer policy validation | AWS's own checks | Needs AWS credentials | No account (REQ-P4-5) |
| OPA or conftest rules | A language made for policy tests | One more tool and language for a reviewer to read | `unittest` covers the same assertions with no new dependency |
| Prose in `SOLUTION.md` only | No code | Nothing fails when a policy drifts | Untestable |

## Trade-offs

The tests check the properties the author thought of, not the IAM evaluation logic, so a policy can pass them and still behave otherwise in AWS. Automated checks on every pull request (SEC-DP4) come at the price of that fidelity, and the AWS acceptance plan repeats the denials against STS and S3.

## Consequences

### Positive

- The tests fail when a role lacks a trust policy, when a trust policy is not exact or not bound to the audience, when two roles share a subject, when a subject does not pin the environment and the workflow, and when an action is a wildcard.
- They also fail when a deploy role can write artifacts, a record write leaves its own prefix, a build role writes the other app's paths, a bucket allows requests without TLS, an unconditional write is allowed, the overwrite exception covers more than `index.html`, records or artifacts can be deleted, or a manifest prefix has more than one writer.
- The plan check fails when a planned policy differs from its document, when a role gets a managed or attached policy, when an endpoint has no policy outside the accepted list, or when an ARN in a document names a role, bucket, deployment group, alarm or other resource that no plan creates.

### Negative

- The placeholders have to be filled in for each account before anything is applied.

### Risks

- The append-only guarantee rests on the S3 condition keys `s3:if-none-match` and `s3:ObjectCreationOperation`, checked against the S3 documentation at writing time. A change in their meaning would weaken the guarantee, so the acceptance plan sends an unconditional write and expects a denial.

## Verification

`python3 -I infra/policies/test_policies.py` runs in the delivery job of `ci.yml` and in `scripts/terraform-check.sh`, which also compares the offline plans with the documents (offline test). The denials against STS and S3 belong to the AWS acceptance plan (cloud run).

## Reopen when

A policy needs a value that only exists after apply, beyond the distribution ID, or the plans can no longer be produced without an account.
