# ADR-P4-0001: Production ready defined as the eleven properties G1 to G11

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P4-4, REQ-P4-6 |
| Principles | OPS-DP3, OPS-DP4, SEC-DP4, REL-DP5 |
| Supersedes | none |

## Context

The task asks the submission to decide what production ready means and to make both pipelines meet it (REQ-P4-4). The challenge gives no service level objective, no compliance regime and no AWS account (REQ-P4-5). A definition borrowed from a maturity model would name goals that nothing in this folder can show. A reviewer needs each property tied to a mechanism they can read and a test they can run.

## Decision

Production ready means eleven properties, G1 to G11 in `SOLUTION.md`: verified merges, build once, traceable versions, gated promotion with records nobody can forge, safe rollout with automatic rollback, one-action manual rollback, no long-lived credentials, a hardened pipeline, ordered and compatible deploys, controlled dependencies, and visible failures. Each property names the workflow, script or policy that implements it and the test that checks it.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Green tests and a deploy step per app | Small and fast to build | Says nothing about rollback, credentials, promotion evidence or the order between the two apps | Leaves the hard parts of production undefined |
| SLSA levels or DORA metrics as the definition | Recognized vocabulary | DORA metrics need months of delivery history that a new repository lacks, and a SLSA level grades the build only | Cannot be verified inside the submission. SLSA provenance still appears inside G3 |
| A long checklist of known practices | Looks complete | Items without a test turn into claims | Every property here has to be checkable |

## Trade-offs

Some properties rest on GitHub settings outside the code: the ruleset on `main` (G1), environment reviewers and branch rules (G4), and the OIDC subject template (G7). The repository documents those settings in `SOLUTION.md` and checks their effects where a job can observe them, such as the `sub` claim that `scripts/oidc-claims.sh` reads. Automation (OPS-DP3) therefore stops at what a workflow can see, and the rest is a written prerequisite.

## Consequences

### Positive

- Every other ADR in this folder implements one or more of the eleven properties, so the list doubles as the review checklist.
- `ci-gate` gives the ruleset one required check for G1, and `scripts/summary.sh` gives every deploy the same job summary for G11.

### Negative

- Eleven properties take more pipeline code than a minimal deploy: scripts, fakes, policy documents and their tests.

### Risks

- A property without a running test becomes a claim. The traceability matrix in `SOLUTION.md` names the verification kind of each property, so a check that needs AWS stays labelled as a cloud run.

## Verification

The traceability matrix in `SOLUTION.md` maps each property to its tests (review). `tools/trace_check.py` fails on a decision without a requirement, a principle or a verification (offline test).

## Reopen when

A real environment shows an incident class that none of G1 to G11 covers, or a compliance regime with its own control list applies to the workload.
