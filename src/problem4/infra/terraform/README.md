# Terraform for the section 8 prerequisites

This folder holds the infrastructure that `SOLUTION.md` section 8 lists as prerequisites. None of it has ever been applied. `scripts/terraform-check.sh` validates it and plans it offline, with mock credentials and no network, and compares every policy in the plans with the tested documents in `infra/policies/`.

## Roots and accounts

| Root | Account (assumption A4) | Creates |
|---|---|---|
| `roots/delivery` | Delivery | Artifact and manifest buckets with versioning, SSE-S3, enforced ownership, retention tags and the G4 bucket policies. The GitHub OIDC provider and the roles `backend-build` and `frontend-build` |
| `roots/environment` with `staging.tfvars` | Staging | VPC with public and private subnets, an S3 gateway endpoint, five interface endpoints (`ssm`, `ssmmessages`, `codedeploy`, `codedeploy-commands-secure`, `logs`) and no NAT gateway. ALB, launch template and Auto Scaling group of at least 2 instances with instance refresh. CodeDeploy application, deployment group and the two G5 alarms. Frontend bucket and CloudFront distribution with OAC, the rewrite function and a security headers policy. The GitHub OIDC provider and the roles `backend-staging-deploy`, `frontend-staging-deploy`, `backend-instance` and `backend-codedeploy` |
| `roots/environment` with `production.tfvars` | Production | The same set for production, with `backend-production-deploy` and `frontend-production-deploy` |

Both roots read `common.tfvars`. Every trust, permission, bucket and endpoint policy comes from a JSON file in `infra/policies/`, read with `file()`, and `templatestring()` fills in its `<PLACEHOLDER>` tokens. No policy is written in HCL and no managed policy is attached. The Content-Security-Policy of the distribution comes from `infra/policies/content-security-policy.txt`, with the API origin of `frontend/config/<env>.json` in `connect-src`. The tfvars files use AWS documentation account IDs, `example.com` hosts and `example-*` bucket names.

## Running the check

```bash
bash scripts/terraform-check.sh
bash scripts/terraform-check.sh --update-lock
```

The script needs Docker, jq 1.6 or later, Python 3.9 or later and shellcheck, and it runs Terraform 1.16.6, tflint 0.61.0 and trivy 0.76.1 from images pinned by digest without any AWS credential. Only `terraform init` and `terraform providers lock` have network, to download hashicorp/aws 6.69.1. Validate, plan, show, tflint and trivy run with `--network none`, so a plan that passes made no AWS call.

The plan steps cover the delivery root and the environment root once per tfvars file. `scripts/plan-policies.py` then reads each plan:

- Every role trust, inline role policy, bucket policy and endpoint policy must equal its document in `infra/policies/`, rendered with the variables of that plan. The document is chosen by name: `trust/<role>.json`, `permissions/<role>.json`, `buckets/<bucket>.json` and `endpoints/<service>.json`.
- Two documents per environment wait for the distribution ID and stay unknown until apply: the frontend deploy permissions and the frontend bucket policy. They must be unknown in the plan, and they must render to JSON with a stand-in ID.
- An IAM resource other than a role, an inline role policy, an instance profile or the OIDC provider fails the step, and so does a role with `managed_policy_arns` or `inline_policy`. An endpoint without a policy fails unless `ENDPOINTS_WITHOUT_POLICY` lists its service.
- The `policy links` step checks every ARN in those documents against the three plans: each role, bucket, CodeDeploy application, deployment group and configuration, alarm, log group, target group, Auto Scaling group and SSM parameter must be created by a plan, or be a role in `EXTERNAL_ROLES`. Renaming a resource on one side only fails here.

`infra/policies/test_policies.py` runs first, so the properties it tests on the documents hold for the planned policies too. The user data of the launch template is decoded from each environment plan and checked with shellcheck.

A plain run initializes with `-lockfile=readonly` and fails when `roots/*/.terraform.lock.hcl` is missing or stale. `--update-lock` rewrites both lock files instead: `terraform init`, then `terraform providers lock` for linux_amd64 and linux_arm64, the two platforms the Terraform image runs on. With a read-only lock file that lacks the h1 hash of the runner's platform, init still passes but validate and plan refuse the provider, so commit both lock files after every update.

## Apply order

Neither root declares a backend, because `terraform plan` refuses to run after `init -backend=false` when one exists. Before any apply, add an S3 backend with `use_lockfile = true` to each root, one state per account. Then:

1. Apply the environment root with `-var=bootstrap=true`, staging first, then production. The artifact and manifest bucket policies name the deploy roles and `backend-instance` of both accounts, and S3 rejects a bucket policy whose role principals do not exist yet. With `bootstrap`, the Auto Scaling group uses EC2 health checks, because no instance can pass the target group health check before the first release.
2. Apply the delivery root.
3. Upload the Node.js runtime to `s3://<artifact_bucket>/backend/runtime/node-v<version>-linux-x64.tar.xz`, where the version comes from `backend/.node-version`, with `put-object --if-none-match '*' --checksum-algorithm SHA256`.
4. Start an instance refresh of `backend-<env>` in each environment. The instances of step 1 could not download the runtime, so their user data stopped before it installed the CodeDeploy agent.
5. Create the DNS records listed in the `dns_records` output.
6. Set the GitHub variables from the `github_repository_variables` and `github_environment_variables` outputs.
7. Run the first backend deploy. `deploy-backend.sh` does not read the alarms on a first deploy, because the `UnHealthyHostCount` alarm stays raised until every instance serves a release.
8. Apply the environment root again without `bootstrap`, which turns on ELB health checks. From then on, an instance that joins the group gets the last successful revision through the CodeDeploy launch hook.

Destroying the delivery buckets needs the `retention-admin` role, because their policies deny object deletes to every other principal.

## Changing the Node.js version

The instances install the runtime that `backend/.node-version` names when the environment root is planned, and the `ValidateService` hook fails a release whose `version.json` names a newer runtime than the instance runs. A version change therefore reaches the instances before it reaches a release:

1. Add the checksum of the new tarball to `backend/node-sha256.txt` and upload the tarball as in step 3 of the apply order.
2. From the branch that changes `backend/.node-version`, apply the environment root of staging, then production. The instance refresh replaces every instance, and the running release keeps working on the newer runtime.
3. Merge the branch. The CD pipeline builds the release with the new runtime and deploys it.

If the branch is merged first, the deploy fails `ValidateService` on the first instance and returns to the previous release with exit code 3.

## Prerequisites outside Terraform

- An ACM certificate for the API host in the region of the environment.
- An ACM certificate for the frontend host in us-east-1.
- The DNS zone.
- The runtime object of step 3.
- One S3 state backend per account.
- The GitHub settings of `SOLUTION.md` section 6.4.

## Accepted exceptions

Each trivy exception is a `#trivy:ignore` line above the resource, and `ACCEPTED_FINDINGS` in `scripts/terraform-check.sh` lists it again with its reason. There is no ignore file. The trivy step also scans a copy of this folder without the ignore lines, and it fails when the findings of that scan, the ignore lines and the accepted list differ.

| ID | Resource | Reason |
|---|---|---|
| AWS-0053 | `aws_lb.this` in `modules/backend` | Public API that browsers call |
| AWS-0011 | `aws_cloudfront_distribution.this` in `modules/frontend` | No WAF: static files only, the origin is private behind OAC |
| AWS-0132 | `aws_s3_bucket_server_side_encryption_configuration.this` in `modules/frontend` and `modules/delivery` | SSE-S3, because the CloudFront principal, the deploy roles and the cross-account readers hold no KMS grant |

The policy steps read two more lists from the same script:

| List | Entries | Reason |
|---|---|---|
| `ENDPOINTS_WITHOUT_POLICY` | `ssmmessages`, `codedeploy`, `codedeploy-commands-secure` | Whether these services accept an endpoint policy shows only in `describe-vpc-endpoint-services`, which needs an account |
| `EXTERNAL_ROLES` | `retention-admin`, `frontend-asset-cleanup` | Roles the bucket policies name for deletes, created outside this folder |

## Known gaps

- No WAF on the ALB or the distribution.
- No VPC flow logs, and no ALB, CloudFront or S3 access logs.
- SSE-S3 instead of a customer managed KMS key.
- No cleanup role, which `SOLUTION.md` section 7 leaves out.
- The `ssmmessages`, `codedeploy` and `codedeploy-commands-secure` endpoints keep the AWS default policy. Give each one a policy from `infra/policies/endpoints/` once `VpcEndpointPolicySupported` is true for it, and remove it from `ENDPOINTS_WITHOUT_POLICY`.
- The `backend-codedeploy` permissions follow the CodeDeploy guide for an Auto Scaling group with a launch template. Only the first staging deploy of the AWS acceptance plan confirms that the set is complete.
- Syslog reaches the fleet log group as one stream per instance, with no dedicated stream for the backend service.
