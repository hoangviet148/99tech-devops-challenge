# ADR-P3-0008: Current LTS runtimes, pinned digests, Postgres major kept

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-2, REQ-P3-4 |
| Principles | SEC-DP4, SEC-DP3, OPS-DP4 |
| Supersedes | none |

## Context

The API runs Node 20, which reached end of life on 2026-04-30, and nginx runs 1.25, past end of life since 2024-05-29 (F11). `npm install` without a lockfile resolves new versions on every build, the API runs as root, and tags float. With trivy 0.76.1 on 2026-11-04, the template images carry these HIGH and CRITICAL findings: nginx 176 and 21, the API 25 and 1, Postgres 87 and 2, Redis 32 and 1.

## Decision

The API builds in two stages from `node:24-alpine` (LTS until 2028-04-30): `npm ci --omit=dev` against a committed lockfile, then a runtime stage without npm, corepack or yarn that runs as UID 1000. nginx moves to 1.30, Postgres stays on major 15 at 15.19 (supported until 2027-11-11), Redis moves to 7.4, and every image is pinned by digest.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Node 22 LTS | Smaller jump from 20 | End of life on 2027-04-30, one year earlier | Shorter runway for the same migration effort |
| Distroless Node images | Smaller attack surface, no shell | Healthchecks need a Node-based probe, harder to debug | Debuggability matters more for a stack under diagnosis |
| Upgrade Postgres to 17 or 18 now | Longer support | A data migration that fixes none of the reported symptoms | Belongs in the prevention plan, not in a stabilization change |
| Keep floating tags | No pin maintenance | Builds change without a commit | Not reproducible |
| Postgres 15.19 on the Debian image | Same C library as the template, so an existing volume keeps its collations | More OS packages to patch than the Alpine image | The local volume is disposable, and a new volume starts clean |
| `apk upgrade` in local Dockerfiles for nginx and Postgres | The remaining OS findings drop at once | Two more images to build, and package versions float again inside a pinned digest | The next official rebuild closes the same gap with a digest bump |

## Trade-offs

Pinned digests stop silent updates, so updates need automation (Renovate or Dependabot) to stay current. Alpine uses musl, which is fine while the API has no native modules.

## Consequences

### Positive

- Reproducible builds and a scanner baseline that only moves with a commit.
- The API process has no root privileges inside its container.

### Negative

- A Postgres major upgrade remains open work before 2027-11-11.

### Risks

- After the change, `postgres:15.19-alpine` keeps 25 HIGH and 1 CRITICAL findings, all in the Go standard library compiled into `gosu`, which the entrypoint runs once to drop root. `nginx:1.30-alpine` keeps 5 HIGH and 1 CRITICAL in curl, libcurl, libexpat and brotli-libs. Both pins are the newest builds of their tags on 2026-11-04, so the fixes arrive with the next upstream rebuild and a digest bump.
- The Debian image created data directories with glibc collations, and Alpine uses musl. Postgres warns about a collation version mismatch on such a volume, so a volume from the template needs `docker compose down -v` once. A production database never changes its C library in place.
- A CVE with no Alpine fix. Trivy in CI surfaces it, and the distroless option above becomes the fallback.

## Verification

`scripts/image-gate.sh` runs trivy and hadolint on the template and on this stack (local run), and the full S1 to S12 run uses the pinned images (local run). After the change the API image has no HIGH or CRITICAL finding, Redis has none, and hadolint reports none.

## Reopen when

Postgres 15 is within six months of end of life, or a HIGH or CRITICAL finding has no fix in the pinned Alpine base.
