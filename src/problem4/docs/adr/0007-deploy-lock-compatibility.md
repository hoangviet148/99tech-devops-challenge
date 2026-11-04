# ADR-P4-0007: One deploy lock per environment and a compatibility gate

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-1, REQ-P4-2, REQ-P4-4 |
| Principles | OPS-DP4, REL-DP5 |
| Supersedes | none |

## Context

The two apps deploy independently into the same two environments. A frontend that calls an API version the backend does not serve breaks its users, and a backend rollback can remove an API version a live frontend still calls. Two runs deploying into one environment at once can interleave, so a frontend could activate against a backend in the middle of a rollback.

## Decision

Every deploy and rollback job of either app takes the concurrency group `deploy-<env>` with `cancel-in-progress: false`, and inside it `scripts/check-forward.sh` refuses a SHA that does not descend from the release deployed in that environment, unless the run is a rollback. Each frontend release records `min_backend_api` from `frontend/contract.json`, and activation requires the backend's `/version` in that environment to report at least that `api_version`. A backend deploy refuses a release below the `min_backend_api` of the last two frontend records of the environment, and a failed backend release never rolls back below that value.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| One lock per app | More deploys in parallel | A frontend activation and a backend rollback in one environment can race | The race this decision removes |
| One global lock for both environments | Simplest ordering | A staging deploy delays a production rollback | Slows recovery |
| Deploy both apps together as one release | No version skew | A frontend fix waits for a backend deploy | Gives up independent deploys |
| Version negotiation in the SPA | Tolerates skew | More client code, and old clients still break when an API disappears | Does not stop the rollback that removes the API |

## Trade-offs

The shared lock serializes both apps within an environment, so a long backend deploy delays a frontend fix (OPS-DP4). GitHub keeps at most one pending run per concurrency group, so staging follows "latest commit wins" and production deploys the release chosen at approval. A vetoed backend rollback exits 5 and pages instead of restoring the previous release, and a person then rolls the frontend back first or rolls the backend forward (G5).

## Consequences

### Positive

- Deploys into one environment never overlap, whichever app or workflow started them.
- An incompatible pair is refused before anything changes, ahead of the first frontend upload and ahead of the CodeDeploy call.

### Negative

- The backend reads only the last two frontend records, as a stand-in for every frontend release inside the A8 window and every frontend rollback target.
- The contract test checks the current frontend against the current `backend/openapi.yaml`. Client tests of older live releases do not run against a new backend document.
- The forward-only check needs the full git history in the deploy job, which checks out with `fetch-depth: 0`.

### Risks

- An older release that still serves open tabs could need an API version the last two records do not show. The version check moves those tabs within one interval (A8), and a backend change keeps an API version until no recorded frontend release needs it.

## Verification

`scripts/tests/test-check-forward.sh` checks a descendant, an ancestor with and without rollback, a diverged commit and a deployed commit missing from the checkout. `scripts/tests/test-deploy-frontend.sh` checks that an older backend blocks activation before any upload, and `scripts/tests/test-deploy-backend.sh` checks that an incompatible release is refused and that a rollback below the frontend's needs exits 5 without a deployment (offline test). `frontend/test/contract.test.ts` runs against `backend/openapi.yaml` whenever either changes (offline test). The queueing of the concurrency group shows on the demo repository (GitHub demo).

## Reopen when

The apps need parallel deploys in one environment, or an API change cannot stay backward compatible for one version check interval plus the frontend rollback targets.
