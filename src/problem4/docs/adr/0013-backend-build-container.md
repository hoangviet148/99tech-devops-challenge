# ADR-P4-0013: Backend bundle built in an Amazon Linux 2023 container from the official Node tarball

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-1, REQ-P4-4 |
| Principles | OPS-DP3, REL-DP5, SEC-DP4 |
| Supersedes | none |

## Context

The bundle's `node_modules` must load on Amazon Linux 2023 x86_64 instances (A2), and a build on the Ubuntu runner does not prove that for native modules. The instances run Node from the official tarball under `/opt/node`, so the build has to use the same version. A rerun of a CD workflow rebuilds the artifact, and the conditional write of the publish step fails when the new bytes differ from the stored object.

## Decision

`scripts/build-backend.sh` downloads `node-v<version>-linux-x64.tar.xz` for the version in `backend/.node-version`, checks it against `backend/node-sha256.txt`, and mounts the extracted runtime read-only at `/opt/node` in the pinned `amazonlinux:2023.12.20261021.0` image. There `npm ci --ignore-scripts`, `tsc` and `npm ci --omit=dev --ignore-scripts --no-bin-links` run as the invoking user, and the build fails when production dependencies contain a `.node` file or a `binding.gyp`. `scripts/pack-tgz.py` packs the bundle with sorted entries, owner 0, normalized modes, the commit time (or `SOURCE_DATE_EPOCH`) as every mtime and a gzip header without a timestamp, so a rebuild of one commit gives the same digest.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Build on the Ubuntu runner with `setup-node` | Fast, no container | `node_modules` built against the runner's C library | A native module could fail on EC2 only |
| Node from the Amazon Linux package repository | Signed packages and `dnf` updates | Another Node build and release cadence than the pinned version | CI and the instances would run different runtimes |
| Build on EC2 or in CodeBuild | The exact target platform | AWS for every build | No account (REQ-P4-5) |
| `tar -czf` | One command | Timestamps and owners differ per run, and macOS adds extended attributes | A rebuild would conflict with the published artifact |

## Trade-offs

The container adds an image pull and a Node download to every backend build, so build time goes to reproducibility (OPS-DP3, REL-DP5). Dependabot tracks neither the image digest nor the checksum file, which leaves their updates as a manual part of SEC-DP4.

## Consequences

### Positive

- CI and the build container run the version in `backend/.node-version`, and `version.json` records it. `ValidateService` refuses a release on an instance whose runtime is older, so a release never runs on an older runtime than the one it was built and tested with. The instances follow `backend/.node-version` once the environment root is applied, and the README of `infra/terraform/` orders a change: runtime first, then the release.
- A rerun publishes identical bytes, so `put_immutable` treats it as a no-op.
- `--ignore-scripts` keeps the install scripts of dependencies out of the build.
- The bundle carries `appspec.yml` at its root, `dist/`, `deploy/hooks/`, the systemd unit and a `version.json` with the SHA, the commit time, the `api_version` of `backend/openapi.yaml` and the Node version of the build.

### Negative

- The same digest depends on the runner's Python `tarfile` and `zlib` producing the same stream. A change there shows up as a failed conditional write on a rerun, never as a silent overwrite.
- `backend/node-sha256.txt` also lists the arm64 tarball for local builds, while the instances are x86_64.

### Risks

- A future dependency that needs its install script builds broken under `--ignore-scripts`. The native addon guard catches compiled addons, and the smoke test and `ValidateService` catch a bundle that does not start.

## Verification

Two builds of the same commit compare their digests (local run). The build job of `backend-cd.yml` runs on the demo repository (GitHub demo). `scripts/tests/test-hooks.sh` runs the deploy hooks in the same base image (offline test).

## Reopen when

The backend gains a dependency with a native addon, or the instances move to arm64, which changes the tarball and the image platform.
