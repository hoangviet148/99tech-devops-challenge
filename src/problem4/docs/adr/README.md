# Problem 4 architecture decision records

Each record follows the format in `template.md`: context, decision, alternatives with their trade-offs, consequences, verification and the trigger that would reopen it. Requirement and principle IDs, the assumptions A1 to A8 and the properties G1 to G11 are defined in `../../SOLUTION.md`.

| ADR | Decision | Status | Date |
|---|---|---|---|
| [ADR-P4-0001](0001-production-ready-properties.md) | Production ready defined as the eleven properties G1 to G11 | accepted | 2026-11-04 |
| [ADR-P4-0002](0002-subtree-split.md) | Workflows stay under `src/problem4`, live runs use a subtree split | accepted | 2026-11-04 |
| [ADR-P4-0003](0003-codedeploy-rolling.md) | Backend deploy through CodeDeploy in-place rolling with fleet checks | accepted | 2026-11-04 |
| [ADR-P4-0004](0004-frontend-release-layout.md) | Frontend release-scoped layout with one-object activation | accepted | 2026-11-04 |
| [ADR-P4-0005](0005-build-once-manifest.md) | Build once into immutable artifacts with a release manifest | accepted | 2026-11-04 |
| [ADR-P4-0006](0006-oidc-roles.md) | One OIDC role per app and environment, subject pinned to the reusable workflow | accepted | 2026-11-04 |
| [ADR-P4-0007](0007-deploy-lock-compatibility.md) | One deploy lock per environment and a compatibility gate | accepted | 2026-11-04 |
| [ADR-P4-0008](0008-verification-without-aws.md) | Verification without AWS through a recording fake CLI and dry runs | accepted | 2026-11-04 |
| [ADR-P4-0009](0009-backend-node-http.md) | Backend on Node.js 24 with `node:http` and no runtime dependencies | accepted | 2026-11-04 |
| [ADR-P4-0010](0010-frontend-vite.md) | Frontend on Vite and TypeScript without a framework | accepted | 2026-11-04 |
| [ADR-P4-0011](0011-supply-chain.md) | Supply chain: pinned actions, attestations, SBOM, workflow linters | accepted | 2026-11-04 |
| [ADR-P4-0012](0012-tested-policy-documents.md) | IAM and bucket policies as tested documents before Terraform | accepted | 2026-11-04 |
| [ADR-P4-0013](0013-backend-build-container.md) | Backend bundle built in an Amazon Linux 2023 container from the official Node tarball | accepted | 2026-11-04 |
| [ADR-P4-0014](0014-minimal-terraform.md) | Minimal Terraform for the section 8 prerequisites, planned offline and never applied | accepted | 2026-11-05 |
