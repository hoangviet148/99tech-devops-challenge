# ADR-P2-0003: Full-disk lab on loop-backed ext4 in a privileged container

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P2-3 |
| Principles | REL-DP2 |
| Supersedes | none |

## Context

The impact column of the cause catalog makes claims that the NGINX documentation does not settle, such as what a client receives when a proxy temp file cannot be written. Filling the production VM to find out is not an option. Filling a container's overlay filesystem fills the Docker host instead and has no ext4 reserve, while mke2fs keeps 5 % of the blocks for root by default. NGINX workers run as `www-data`, so on the real VM they hit `No space left on device` while root can still write.

## Decision

`lab/run.sh --yes` starts the pinned Ubuntu 24.04 image as a privileged container, installs the distro NGINX, and mounts a 16 MiB loop-backed ext4 filesystem on `/var/log/nginx` and `/var/lib/nginx`. It fills that filesystem as `www-data` and records the client-visible result of each check (L0 to L10) in `evidence/lab-*.md`.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| A real Ubuntu 24.04 VM on a local hypervisor or in the cloud | Same kernel and package, LVM growth testable | A hypervisor or a cloud account, minutes to provision | Heavier than the question needs. It stays as the upgrade path |
| Fill a plain container's overlay filesystem | No privileged flag | Fills the Docker host disk, no ext4 reserve | Unsafe for the host and unlike the VM |
| A size-limited tmpfs | No loop device | No root reserve and no ext4 allocation | Misses the reserve case, which explains why root still writes on a full disk |
| No lab, documentation only | No setup | The documentation does not state what a client gets when a temp file write fails | Leaves the impact column unverified |

## Trade-offs

The container runs privileged so that it can attach loop devices, which works against SEC-DP3 ("Apply security at all layers"). The privilege is limited to a local run on a developer machine, with a pinned image and no host path mounted except the lab folder, read-only. LVM growth and journald cannot run in this container, so those rows rely on review.

## Consequences

### Positive

- Claims about client impact come from measurements, and a reviewer can rerun them with one command.
- NGINX logs and temp files share one filesystem in the lab as they do on the VM, so a fill hits both.

### Negative

- Packages come from the Ubuntu archive at run time, so the NGINX patch version can differ between runs. The evidence header records the version that ran.

### Risks

- A Docker VM without a free loop device. The script stops with the `losetup` error and does not fall back to another filesystem.

## Verification

`bash lab/run.sh --yes` (local run), with the results table and the raw command output in `evidence/lab-*.md`.

## Reopen when

The lab has to run in CI on shared runners, where privileged containers are not acceptable, or LVM growth needs a test.
