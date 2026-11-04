# ADR-P5-0003: Withdrawal controls and integrity halts

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P5-1, REQ-P5-2, REQ-P5-3, REQ-P1-12A, REQ-P1-14A |
| Principles | SEC-DP1, SEC-DP2, SEC-DP6, SEC-DP7 |
| Supersedes | none |

## Context

An account takeover becomes a loss at the moment a withdrawal leaves. The Problem 1 ledger already deduplicates trades, checks balanced postings and writes a checkpoint every 60 s. Lag between the ledger, the risk engine and the chains is normal under load. A disagreement at the same checkpoint is not, and trading on wrong balances turns one error into many.

## Decision

Withdrawals pass risk scoring, an address allowlist with a 24 h cooldown for new addresses, velocity limits, step-up MFA and a second approver above a threshold. Posting tables are append-only with no UPDATE or DELETE grant for the application role, and reconciliation compares ledger, risk engine and on-chain balances at the same checkpoint. A diff halts trading and withdrawals for the affected account shards until a rebuild from the ledger shows a zero diff.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| A person reviews every withdrawal | The strongest human check | Slow, and the queue grows with the customer base | Fails REQ-P1-3 as volume grows, and a reviewer under load approves by habit |
| Reconciliation on wall-clock time | A simple schedule | Normal lag looks like a breach and halts trading for nothing | Checkpoints compare states that belong together |
| Alert on a diff and keep trading | No availability cost | Trading continues on balances that may be wrong | Breaks REQ-P1-14A |

## Trade-offs

An integrity halt counts against the 99.95 % availability objective of REQ-P1-12A, which is the price recorded for REQ-P1-14A. The cooldown and the second approver slow withdrawals by design, a cost that customers see.

## Consequences

### Positive

- A stolen session cannot withdraw to a new address for 24 h.
- A diff stops the damage at the shards it affects, while the other shards keep trading.

### Negative

- A bug in reconciliation can halt shards without a real breach.
- The second approver threshold and the velocity limits are not known yet (FN-08).

### Risks

- Two colluding approvers release a fraudulent withdrawal. The hot wallet cap and the velocity limits bound the loss, and the audit log of SC-11 records both approvers.

## Verification

Review: withdrawal policy test cases, and a checkpoint reconciliation test with injected lag and with an injected diff.

## Reopen when

An integrity halt fires on lag without a real diff, or second approvals queue longer than the risk policy allows.
