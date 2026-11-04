# ADR-P4-0014: Minimal Terraform for the prerequisites, planned offline and never applied

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-05 |
| Deciders | Submission author |
| Requirements | REQ-P4-1, REQ-P4-2, REQ-P4-5 |
| Principles | OPS-DP3, REL-DP5, SEC-DP3, SEC-DP4 |
| Supersedes | none |

## Context

The pipelines deploy into the resources that `SOLUTION.md` section 8 lists as prerequisites, and the policy documents of ADR-P4-0012 and the GitHub variables of section 9 refer to those resources by name. A role, bucket or alarm that no infrastructure creates under that name fails only at the first deploy. The documents span three accounts: a delivery account with the artifact and manifest buckets and the build roles, and the staging and production accounts of A4. There is no account to apply anything in (REQ-P4-5). By default the AWS provider validates its credentials with STS before a plan, and data sources for the account ID, the AZs or the AMI call AWS as well.

## Decision

`infra/terraform/` defines the prerequisites in `roots/delivery` and `roots/environment`, the second planned once per environment with `staging.tfvars` or `production.tfvars`, over five modules pinned to Terraform 1.16.6 and hashicorp/aws 6.69.1, and each IAM, bucket and endpoint policy in it is a document of `infra/policies/` read with `file()` and filled in with `templatestring()`. With `offline=true` the provider uses mock credentials and skips its account checks, and no data source calls AWS, so `scripts/terraform-check.sh` validates and plans the three configurations in pinned containers started with `--network none`. Nothing is applied, and no pipeline applies it.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| The list of prerequisites in `SOLUTION.md` only | No infrastructure code to keep up | Nothing compares the names in the policies and variables with real resources | A rename on one side fails at the first deploy |
| Plan and apply pipeline with remote state per account | Infrastructure changes reviewed and applied like the apps | An account per environment, state buckets and an apply role with wide permissions | No account (REQ-P4-5) |
| Data sources for the account ID, the AZs and the AMI | Fewer values in the tfvars files | Every plan needs credentials and calls AWS | The check could not run offline in CI |
| Community modules such as `terraform-aws-modules/vpc` | Less code to write | Resources and policies that `infra/policies/` does not describe | Each one would need an exception in the plan check |

## Trade-offs

Managing change through automation (REL-DP5) stops at the plan. Nothing applies the configuration, no state exists to compare with the accounts, and the apply order in `infra/terraform/README.md` is eight manual steps. A plan with mock credentials checks the configuration against the provider schema and not against AWS, so a missing certificate, an endpoint service that refuses a policy or a service quota shows only at the first apply. The checks run on every pull request that changes their inputs (OPS-DP3, SEC-DP4) at that price. Security at all layers (SEC-DP3) stays incomplete by choice, and the README lists the missing WAF, flow logs, access logs and customer managed KMS key as known gaps.

## Consequences

### Positive

- Each trust, permission, bucket and endpoint policy known at plan time equals its document, so the tests of ADR-P4-0012 cover what an apply would create.
- The `policy links` step fails when an ARN in a document names a role, bucket, deployment group, alarm, log group, target group or Auto Scaling group that no plan creates.
- The outputs `github_repository_variables` and `github_environment_variables` hold the AWS values of section 9. The expected subjects come from the rendered trust policies, so the value set as `OIDC_EXPECTED_SUB` is the subject STS checks.
- The instances install the runtime that `backend/.node-version` names, checked against `backend/node-sha256.txt`, the two files the build reads (ADR-P4-0013).

### Negative

- Neither root declares a backend, so one S3 state backend per account has to be added before the first apply.
- Two documents per environment, the frontend deploy permissions and the frontend bucket policy, stay unknown until the distribution exists. The check renders them with a stand-in ID and checks their JSON and their ARNs, not their planned value.
- The first apply needs a bootstrap pass with EC2 health checks, an upload of the Node.js runtime and an instance refresh, in the order the README gives.
- The gaps the README lists remain: no WAF, no VPC flow logs or access logs, SSE-S3, and three interface endpoints with the default policy.

### Risks

- An offline plan cannot show what AWS refuses at apply. The first staging apply is the first test against an account, and outside offline mode `allowed_account_ids` stops each root from applying in an account other than its own.
- The `backend-codedeploy` permissions follow the CodeDeploy guide for an Auto Scaling group with a launch template. Only the first staging deploy confirms that they are complete.

## Verification

`scripts/terraform-check.sh` runs in the `workflow-lint` job of `ci.yml`. It checks the version pins and the format, runs the policy tests, initializes against the committed lock files, validates, plans the three configurations offline, compares their policies and ARNs with `infra/policies/`, runs shellcheck on the rendered user data, runs tflint, and compares the trivy findings with the accepted list. Its output is in `evidence/terraform-check.txt` (offline test). Applying both roots and running the AWS acceptance plan against them need the accounts of A4 (cloud run).

## Reopen when

An account per environment becomes available, which brings a state backend and a plan and apply pipeline, or a resource needs a value that only an AWS call can return at plan time.
