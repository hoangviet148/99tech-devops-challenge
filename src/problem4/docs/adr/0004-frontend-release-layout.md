# ADR-P4-0004: Frontend release-scoped layout with one-object activation

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-2, REQ-P4-4 |
| Principles | OPS-DP4, REL-DP1, REL-DP2 |
| Supersedes | none |

## Context

The SPA is served from a private S3 bucket through CloudFront with Origin Access Control (A3). Vite emits content-hashed chunks, so an open tab keeps requesting the chunks of the release it loaded. `aws s3 sync --delete` breaks those tabs during a deploy, and a failed upload leaves new HTML that points at missing files. Configuration differs per environment, while the bytes stay the same everywhere (ADR-P4-0005).

## Decision

`scripts/deploy-frontend.sh` uploads `assets/` as immutable files and the files of one release under `releases/<sha>/`, including the `config.json` of the target environment and the release `index.html`, all through conditional writes. It activates the release by copying `releases/<sha>/index.html` over the root `index.html`, the one object the bucket policy lets a deploy overwrite, then invalidates, smoke tests and returns to the previous release when a check fails. The SPA polls `/index.html` without cache for the active release SHA and reloads when it changes, and a chunk load error reloads a tab once per release before the error surfaces.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| `aws s3 sync --delete` of the whole build | One command | Tabs on the old `index.html` break mid-deploy, and a failed upload leaves a mixed state | Not atomic |
| One origin path per release, switched on the distribution | Atomic switch | Each deploy is a distribution change that takes minutes to propagate and needs a wider IAM role | Slower and wider than one object copy |
| CloudFront continuous deployment | Canary by traffic share | A second distribution per environment | Upgrade path for canary releases |
| Configuration baked into a build per environment | No configuration fetch | A different artifact per environment | Breaks build once (ADR-P4-0005) |

## Trade-offs

Old assets stay after each deploy because open tabs and rollbacks need them (REL-DP2), so their removal moves to a cleanup job outside the deploy path. The version check runs every `versionCheckSeconds`, 600 in staging and production, so a tab can stay on a deactivated release for one interval (A8), and retention has to cover that interval plus the longest CloudFront TTL.

## Consequences

### Positive

- Activation and rollback are one object copy, and a rollback needs no rebuild while `releases/<sha>/index.html` exists.
- A redeploy of the same bytes is a no-op, and other bytes under the same SHA fail the job.
- Each release reads `/releases/<sha>/config.json` of its own SHA, so no visitor sees new configuration with old HTML.
- The reload guard keys on `chunk-reload:<sha>` in `sessionStorage`, so a chunk that stays missing cannot loop a tab.

### Negative

- The deploy role can overwrite `index.html` without a precondition, the one exception in the bucket policy.
- Deep links depend on a CloudFront Function that rewrites extension-less paths to `/index.html`, defined with the distribution in `infra/`.

### Risks

- Assets removed too early break tabs on an old release. The rule keeps them 30 days after the release was last active plus the longest CloudFront TTL, and keeps rollback targets whatever their age. The bucket policy reserves deletes for a `frontend-asset-cleanup` role, and the cleanup job is not part of this submission.

## Verification

`scripts/tests/test-deploy-frontend.sh` covers upload order, activation last, conditional writes, failed uploads, failed checks after activation and rollbacks (offline test). `scripts/tests/browser/run.sh` drives Playwright against the fake bucket for activation, rollback, deep links and chunk errors in an open tab (offline test). The browser test against a staging distribution belongs to the AWS acceptance plan (cloud run).

## Reopen when

A release needs a gradual traffic share before full activation, or the retained releases make asset storage a visible cost line.
