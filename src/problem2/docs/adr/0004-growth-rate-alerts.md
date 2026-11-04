# ADR-P2-0004: Alerts on growth rate as well as thresholds

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P2-1, REQ-P2-4 |
| Principles | OPS-DP2, GEN-DP5 |
| Supersedes | none |

## Context

The VM sits "consistently" at 99 %, so a static threshold has been firing or has been muted for some time, and alert fatigue is part of the incident. A threshold alone also reacts late to a fast fill, such as a burst of bot traffic that takes the disk from comfortable to full between two looks. node_exporter exposes `node_filesystem_avail_bytes`, documented as the space available to non-root users, which is the space NGINX workers can still use. Ubuntu also mounts snaps as squashfs images that always report 100 % usage.

## Decision

Five rules in `alerts/disk-rules.yml`: available space under 15 % warns and under 5 % pages, `predict_linear(node_filesystem_avail_bytes[6h], 4 * 3600) < 0` pages, free inodes under 10 % warn, and an NGINX 5xx ratio above 1 % pages. The disk rules read `avail` rather than `free` and select ext4 and XFS only.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Static thresholds only | Simple and familiar | Late on a fast fill, and a stable 99 % fires without end | Misses the fast fill, the case that hurts a single load balancer most |
| Growth rate only | Early warning on a fast fill | A full but stable disk never fires | The scenario itself is a stable 99 % |
| `free_bytes` instead of `avail_bytes` | Matches what root sees | Counts the root reserve that `www-data` cannot use | Fires 3.2 GB late on a 64 GB ext4 disk with the default 5 % reserve |
| Anomaly detection on disk usage | Learns the normal growth | Opaque thresholds, needs history | The VM has no usable history yet |

## Trade-offs

A page on a prediction can fire for a write that stops by itself, such as a large package upgrade, which costs a page against the "actionable" part of OPS-DP2. The 6 h window and the 15 min `for` smooth short bursts, and GEN-DP5 favours acting on the measured trend over waiting for the threshold. The 5xx ratio comes from the access log, so it goes blind when the disk is full and NGINX stops writing that log (lab check L1). The disk rules therefore never depend on the log.

## Consequences

### Positive

- A fast fill pages hours before the thresholds, and a stable 99 % still pages on the threshold.
- Snap mounts and tmpfs never page.

### Negative

- The 5xx rule needs a log exporter on the VM. The rule uses the metric name of prometheus-nginxlog-exporter with the namespace `nginx`.

### Risks

- A full disk silences the log-based 5xx ratio. A probe of the load balancer from outside the VM covers client impact independently of the disk.

## Verification

`alerts/test.sh` runs `promtool check rules` and `promtool test rules` on series for a stable 99 % with a snap mount, a steady fill from 50 %, inode exhaustion, and 5xx ratios of 2 % and 0.5 % (offline test).

## Reopen when

A page from these rules is closed with no action taken, or a disk incident happens without a page from them.
