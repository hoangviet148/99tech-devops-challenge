# ADR-P2-0001: Evidence first, stabilize before root cause

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P2-1, REQ-P2-5 |
| Principles | OPS-DP5, OPS-DP6 |
| Supersedes | none |

## Context

Monitoring reports the only NGINX load balancer VM at 99 % disk usage, and every upstream service sits behind it. The usual reflexes make that worse. `rm` on an active log frees nothing while NGINX holds it open, compression needs free space before it saves any, `apt autoremove` needs space to run, and a restart drops every client connection and erases the deleted-but-open evidence. The full mount may not be `/`, and the filesystem may be smaller than the 64 GB disk, so a command that assumes `/` and ext4 can clean or grow the wrong thing.

## Decision

The runbook first resolves the alerting path into `MNT`, `DEV` and `FSTYPE` and runs only read-only commands until sizes, top writers and a sample of the growing file are saved to `/dev/shm` and off the host. When `MNT` is at 100 % and still growing, it frees a measured amount of known-disposable data on `MNT` or grows the volume online before it looks for the root cause.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Delete the largest files first | Fastest visible drop in usage | Destroys evidence, an open log frees nothing, live data can go | Recovery without a diagnosis brings the incident back |
| Restart NGINX or reboot the VM | Releases deleted-but-open files in one step | Drops every connection on the only load balancer and erases the open-file evidence | Turns a capacity warning into an outage of every upstream |
| Root cause first, no stabilization | Clean diagnosis | A fill that is still growing reaches 100 % during the analysis | Leaves the service exposed while the analysis runs |
| Grow the volume before anything else | Buys time without touching data | An EBS volume never shrinks, and the cause keeps writing | Spends money and hides the cause. It stays as one of the two stabilization options |

## Trade-offs

The procedure is manual, which works against OPS-DP3 ("Safely automate where possible"). An automated cleanup on the only load balancer is the riskiest automation to get wrong, so the steps stay manual until the cause catalog has met real incidents. The growth-rate page of ADR-P2-0004 buys the minutes that reading costs.

## Consequences

### Positive

- The evidence survives the cleanup, so the permanent fix targets the writer that caused the fill.
- Every cleanup and growth command names `MNT` or `DEV`, so none of them lands on the wrong filesystem.

### Negative

- The first minutes go to reading instead of freeing space.

### Risks

- Evidence written to the full filesystem fails or takes the last free blocks. The runbook writes it to `/dev/shm` and copies it off the host.
- A very fast fill reaches 100 % during the evidence step. The growth rate is measured in step 1, and the stabilization branch runs first when the mount is already full and growing.

## Verification

The lab derives `MNT`, `DEV` and `FSTYPE` on the loop-backed filesystem (E0) and shows that `rm` on an open log frees nothing (L4) while `nginx -s reopen` does (L5), both as a local run. The order of the runbook steps is checked by review.

## Reopen when

A second incident has the same cause after its permanent fix, which shows that the recovery for that row should become an automated runbook.
