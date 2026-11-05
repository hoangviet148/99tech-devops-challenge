# ADR-P4-0010: Frontend on Vite and TypeScript without a framework

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-2, REQ-P4-4 |
| Principles | OPS-DP4, SEC-DP3 |
| Supersedes | none |

## Context

The challenge ships no frontend (A1). The deploy design of ADR-P4-0004 rests on content-hashed chunks, a lazily loaded chunk and a release SHA inside `index.html`, so the app has to produce all three, and its tests have to run in CI.

## Decision

The frontend is TypeScript built by Vite 8.3.5 and tested with Vitest 5.1.0, without a UI framework. Vite emits content-hashed assets and `.vite/manifest.json`, `index.html` carries `<meta name="release-sha">` from `VITE_RELEASE_SHA`, and the `/details` view is a lazily imported chunk.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| React or Vue | Component model and a familiar skill set | Runtime dependencies and a larger bundle for two views | The pipeline is the subject here, not the UI |
| Plain HTML and scripts without a bundler | No toolchain | No content hashing and no lazy chunks, so cache busting and chunk error handling could not be shown | Removes what ADR-P4-0004 has to test |
| Next.js static export | Routing and prerendering | A framework build model on top of the bundler | More moving parts than an SPA with two views |

## Trade-offs

The app stays small, so each release stays small and easy to revert (OPS-DP4), and the bundle carries no framework code (SEC-DP3). The price is hand-written DOM code that a framework would replace once the UI grows.

## Consequences

### Positive

- Asset names change with their content, which the one-year `immutable` cache header relies on.
- The lazy `/details` chunk gives the browser test a real chunk to break and recover.
- Configuration arrives at runtime from `/releases/<sha>/config.json` and passes `parseConfig`, which requires HTTPS outside localhost and a `versionCheckSeconds` between 1 and 3600.

### Negative

- The development dependencies (Vite, Vitest, Biome, TypeScript and yaml) still need audits and updates.

### Risks

- A Vite major upgrade could rename chunks or change the `vite:preloadError` event that the reload guard listens to. The browser test fails when the reload stops working.

## Verification

`npm test` (`frontend/test/release.test.ts`, `config.test.ts` and `contract.test.ts`) and `npm run build` run in the frontend job (offline test). The Playwright suite in `scripts/tests/browser/` runs against the built release (offline test).

## Reopen when

The UI needs shared state across views, or more views than the two it has today.
