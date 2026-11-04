# ADR-P4-0009: Backend on Node.js 24 with `node:http` and no runtime dependencies

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-1, REQ-P4-4 |
| Principles | SEC-DP3, OPS-DP4 |
| Supersedes | none |

## Context

The challenge ships no backend code (A1), and the pipeline needs real lint, typecheck, test and build steps to be verifiable. Whatever the app depends on at runtime becomes part of every bundle, every audit and the native module risk that ADR-P4-0013 guards against.

## Decision

The backend is a TypeScript app on Node.js 24 (`engines` set to `>=24 <25`, `backend/.node-version` at 24.22.2) built on `node:http` with no runtime dependencies. It serves `/healthz`, `/version` (release SHA, commit time and `api_version`) and `/api/v1/greeting`, answers 405 to methods other than GET and HEAD, keeps idle connections open longer than the ALB idle timeout, and stops on SIGTERM within 10 s.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Express or Fastify | Routing, middleware and a large ecosystem | Runtime dependencies to audit and update, and more bytes per bundle | Three routes need no framework |
| A Go binary | One static file and no runtime on the host | A second toolchain beside the Node frontend | CI needs Node for the frontend anyway |
| Python with FastAPI | Short code | A runtime plus dependencies on the instances | The same dependency cost as Express |

## Trade-offs

Hand-written routing gives up what a framework provides, such as request validation and content negotiation. For three read routes the dependency cost weighs more, so a smaller runtime surface (SEC-DP3) wins over developer convenience, and each release stays small enough to revert without dependency drift (OPS-DP4).

## Consequences

### Positive

- `npm ci --omit=dev` installs nothing, so the bundle carries no third-party runtime code and the native addon guard of the build has nothing to reject.
- `GET /version` reports the SHA that `ValidateService` and the smoke test compare with the release.
- The Node version lives in one file, which CI reads through `setup-node` and the build container through `backend/node-sha256.txt`.

### Negative

- The first real feature that needs a framework brings dependencies, and with them the dependency review the pipeline already enforces.

### Risks

- Dependabot does not track `backend/.node-version`, so a Node patch release is a manual bump of `.node-version` and `node-sha256.txt` together.

## Verification

`backend/test/app.test.ts` and `backend/test/version.test.ts` run through `npm test` in the backend job (offline test). `scripts/smoke.sh backend` and the `ValidateService` hook compare `/version` with the release SHA (offline test, through the fakes and the hook test).

## Reopen when

The API needs request bodies, validation or authentication, at which point a framework earns its dependencies.
