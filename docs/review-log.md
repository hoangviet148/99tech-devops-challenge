# Review log

Every review runs with read-only access to the repository, by a reviewer that did not write the change (ADR-0004). Each finding is checked against the code or the vendor page it cites before it is accepted. Severities: P0 blocks the work, P1 must be fixed or written down as an accepted trade-off before a merge, P2 is advice.

## Before each merge

| Problem | Branch | Verdict | Findings and outcome |
|---|---|---|---|
| Root | `docs/root` | Merged | 15 confirmed (5 P1, 10 P2), fixed in the root changes of this merge |
| 3 | `p3/stabilize` | Merged with open findings | 37 confirmed (7 P1, 30 P2), not applied in this submission |
| 4 | `p4/cicd` and `p4/terraform` | Merged with open findings | 28 confirmed on the pipelines (10 P1, 18 P2) and 5 on the Terraform (1 P1, 4 P2), not applied in this submission |
| 1 | `p1/trading-platform` | Merged with open findings | 41 confirmed (12 P1, 29 P2), fixed in 1831410. A second review confirmed 5 more (3 P1, 2 P2), not applied in this submission |
| 5 | `p5/security-review` | Merged with open findings | 40 confirmed (19 P1, 21 P2), not applied in this submission |
| 2 | `p2/disk-full` | Merged with open findings | 30 confirmed (11 P1, 19 P2) and 3 rejected, not applied in this submission |
