# Full-disk lab

The lab checks every claim in `../SOLUTION.md` about NGINX on a full disk before the claim is relied on. It reproduces the load balancer of the scenario on a filesystem small enough to fill in seconds, and it records what a client sees.

## What it builds

`run.sh` starts `ubuntu:noble-20260930.1`, pinned by digest, as a privileged container and runs `inside.sh` in it. `inside.sh` then does the following:

1. Installs the distro NGINX, `logrotate`, `lsof`, `curl`, `e2fsprogs` and `procps`.
2. Creates a 16 MiB ext4 image with the default 5 % root reserve, attaches it to a loop device and bind-mounts it on `/var/log/nginx` and `/var/lib/nginx`, so access logs and temp files share one filesystem as they do on the VM.
3. Starts NGINX with `nginx.conf`: a load balancer on port 8080 with 16 KiB of proxy buffers and an 8 KiB client body buffer, in front of an upstream on port 8081 that serves a 4 MiB file from outside the small filesystem. The NGINX error log is written outside the small filesystem, so its messages survive the fill.
4. Runs the checks below and prints a Markdown report with a results table and the raw output of every command.

## Checks

| ID | Check | Why it matters |
|---|---|---|
| E0 | `MNT`, `DEV` and `FSTYPE` derived from the path with `mount-vars.sh`, plus `df`, `df -i`, `tune2fs -l` and the temp paths from `nginx -V` | The runbook starts with the same three lines |
| L0 | A 4 MiB response read at 512 KiB/s with free space | Proves that the response spills to a temp file before any fill, and shows that the temp file is already deleted while open |
| L9 | Fill as `www-data`, then write as root | Shows the root reserve: non-root writers stop while root can still write |
| L1 | Two hundred small responses on the full filesystem | Small responses should still return 200 while NGINX drops access log lines after one alert |
| L2 | The 4 MiB response on the full filesystem | Status, bytes received against `Content-Length`, and the curl exit code show how the response ends |
| L3 | A 512 KiB POST body on the full filesystem | Request bodies above the buffer need a temp file |
| L10 | `tune2fs -m 1` on the mounted, full filesystem | Checks the emergency lever of the runbook |
| L4 | `rm` on the open access log | Shows that the space stays used |
| L5 | `nginx -s reopen` after the `rm` | Shows that the reopen frees it |
| L7 | `mv` of the access log without a reopen | Shows NGINX writing to the renamed file until it reopens |
| L6 | `logrotate -f` with `logrotate-nginx.conf` | The package rules with `nginx -s reopen` as `postrotate`, since `invoke-rc.d` does nothing in a container |
| L8 | An 8 MiB ext4 image with 64 inodes filled with empty files | Shows `No space left on device` while blocks are free |

## Run it

```bash
bash src/problem2/lab/run.sh --yes
```

The report lands in `src/problem2/evidence/lab-<UTC time>.md`. Pass `--out FILE` to choose another path. A failed run keeps its partial report next to the target with the suffix `.partial`.

## Requirements and side effects

- Docker that allows privileged containers, with at least two free loop devices on the host or in the Docker VM. Without a free loop device the run stops at `losetup` and says so.
- Network access from the container to the Ubuntu archive. The packages are not pinned, so the report header records the NGINX version that ran.
- The images live inside the container. The loop devices are detached and the container is removed at the end, also when a check fails.

## Limits

- LVM growth and journald need a full VM with systemd, so their rows in the cause catalog rely on review.
- The container runs on the kernel of the Docker VM, not on the Ubuntu 24.04 kernel of the production VM. A difference in ext4 between those kernels would only show up in a run on a real VM.
