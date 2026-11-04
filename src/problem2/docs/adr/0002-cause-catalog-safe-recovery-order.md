# ADR-P2-0002: Cause catalog with a safe recovery order per cause

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P2-2, REQ-P2-3, REQ-P2-4 |
| Principles | OPS-DP6, OPS-DP7 |
| Supersedes | none |

## Context

The challenge asks for the expected causes, the impact of each and the recovery steps for each. On a VM whose only service is NGINX, eleven causes can fill the disk: NGINX logs, a deleted log held open, a verbose error log, the proxy cache and temp files, the journal, package caches, core dumps, a filesystem smaller than the disk, another writer, inode exhaustion and SSH brute force. Several recoveries are unsafe in a generic order. A full cache purge sends every request to the upstreams at once, `journalctl --vacuum-size` frees nothing until the active file is rotated, and `apt autoremove` needs space to run.

## Decision

The answer is a catalog with one row per cause that names the first signal, how to confirm it, the impact on the load balancer, an immediate recovery ordered from reversible to destructive, and a permanent fix. Steps that need free space, such as compression or package removal, come after a step that creates headroom.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| One generic cleanup script (`apt-get clean`, journal vacuum, delete old logs) | Fast and repeatable | Deletes evidence, misses the actual writer, runs unsafe steps on a full disk | Treats the symptom in every incident and hides the cause |
| A decision tree by symptom only | Short | Cannot tell an open deleted file from a large file, or inodes from blocks | Misdiagnoses the cases that mislead most |
| NGINX causes only | Focused on the one service | The OS and other writers fill the same filesystem | The scenario names NGINX as the only service, not as the only writer |

## Trade-offs

Eleven rows take longer to read than one script runs, which works against OPS-DP3 ("Safely automate where possible"). The catalog is read once per incident, each row fits on one line of a table, and the locate step of the runbook narrows the choice to one or two rows before anyone reads further.

## Consequences

### Positive

- Each recovery fits its cause, so no step frees the wrong data or needs space that is not there.
- The impact column tells on-call staff what clients see while the cause is still being fixed.

### Negative

- The catalog needs an update whenever the role of the VM changes.

### Risks

- A cause outside the catalog. The locate step (`du -x`, `lsof +L1`, `df` against `du`) finds any writer, and the catalog only speeds up the known ones.

## Verification

The NGINX rows are checked by the lab (L0 to L8, local run). The other rows are checked by review against the cited vendor pages.

## Reopen when

An incident has a cause that is not in the catalog, or a recovery step from the catalog makes an incident worse.
