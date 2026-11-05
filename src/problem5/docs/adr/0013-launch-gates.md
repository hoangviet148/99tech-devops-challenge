# ADR-P5-0013: Compliance and prelaunch exercises as launch gates

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-3, REQ-P5-4, REQ-P1-2, REQ-P1-13A |
| Principles | FSI-DP3, FSI-DP4, SEC-DP7, REL-DP2, GEN-DP6 |
| Supersedes | none |

## Context

The assumed jurisdiction is Singapore under the MAS Payment Services Act (FN-01), which legal has not confirmed yet. An exchange that moves real assets without AML onboarding, transaction monitoring, reporting and Travel Rule controls puts at risk the licence it needs to operate. Recovery from ledger corruption, signer compromise and credential theft has never run on this design.

## Decision

AML onboarding, transaction monitoring, reporting and Travel Rule controls, confirmed by legal and compliance, gate the launch with real assets, and until then only a sandbox with test assets runs. Launch also waits for five prelaunch activities: a restore from ledger corruption, a signer compromise with key revocation and fund migration, a credential revocation, an incident response tabletop, and an external penetration test.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Launch first and add AML controls in the next iterations | An earlier launch | Real assets move without monitoring | Regulatory exposure from the first day |
| Run the exercises after launch | An earlier launch | The first rehearsal happens during a real incident | Fails SEC-DP7 and REL-DP2 |
| Exercises on paper only | Cheap | Procedures that never ran hide gaps | The tabletop is one activity, and the restore, the signer compromise and the revocation run on real systems |

## Trade-offs

The launch date moves with the legal confirmation and with the exercises, which trades time to market for FSI-DP3 and SEC-DP7.

## Consequences

### Positive

- Launch day is not the first time recovery runs.
- Real assets never move without AML controls.

### Negative

- Legal work sits on the critical path of the launch.

### Risks

- The jurisdiction differs from the assumption. SC-14 then changes content and stays a gate.

## Verification

Review: the launch gate checklist, with one entry per control and per exercise and the evidence for each.

## Reopen when

Legal confirms a jurisdiction with different requirements, or an exercise fails its exit criteria.
