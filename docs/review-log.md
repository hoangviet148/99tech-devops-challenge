# Review log

Every review ran with read-only access to the repository, by a reviewer that did not write the change (ADR-0004). Each finding was checked against the code or the vendor page it cites before it was accepted. Severities: P0 blocks the work, P1 must be fixed or written down as an accepted trade-off before a merge, P2 is advice.

## Before execution: the plan

| Round | Reviewed | Verdict | Findings |
|---|---|---|---|
| 1 | Revision 1 of the plan | rework | 8 P0, 32 P1 |
| 2 | Revision 2 | rework | 3 P0, 18 P1 and 3 P2, all new. Of the 40 findings of round 1, 14 were resolved, 25 partly and 1 not |
| 3 | Revision 3 | execute after blocker fixes | Of the 50 open items, 33 resolved and 17 partly, with 3 new findings. The open work split into 9 blocker fixes and 4 details for the `SOLUTION.md` files |
| 4 | The 9 blocker fixes in revision 4 | rework of one row | 8 fixed, one not yet, plus 2 wording contradictions |
| 5 | The 3 open items in revision 5 | execute | No new contradiction, no open blocker |

Four items carried over into the solutions as planned: the crash cases of the custody protocol (Problem 5, section 7), the cost prices (Problem 1, section 8), the sampling method of the pool health scenario S10 (Problem 3) and the fields of the trade-off register (Problem 1, section 13).

## Before each merge: the solutions

| Problem | Branch | Verdict | Findings and outcome |
|---|---|---|---|
| 3 | `p3/stabilize` | `<PENDING>` | `<PENDING>` |
| 4 | `p4/cicd` | `<PENDING>` | `<PENDING>` |
| 1 | `p1/trading-platform` | `<PENDING>` | `<PENDING>` |
| 5 | `p5/security-review` | `<PENDING>` | `<PENDING>` |
| 2 | `p2/disk-full` | `<PENDING>` | `<PENDING>` |
