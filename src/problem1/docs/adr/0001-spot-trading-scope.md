# ADR-P1-0001: Spot trading subset as the feature scope

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P1-1, REQ-P1-5 |
| Principles | GEN-DP4, OPS-DP1 |
| Supersedes | none |

## Context

REQ-P1-1 asks for a trading system with features similar to Binance, using a chosen subset. Binance also runs futures, margin, P2P, earn and staking, fiat rails and a launchpad, each with its own risk model. The subset has to exercise the properties that make an exchange hard: a deterministic order sequence, balances that never go negative, and custody of customer funds. Section 2.1 of `SOLUTION.md` lists the scope.

## Decision

The scope is signup and login with MFA, spot trading on a small set of pairs with limit and market orders and cancel, order book and trades over REST and WebSocket, balances on a double-entry ledger, and Bitcoin and Ethereum deposits and withdrawals through async workers. Derivatives, P2P, earn, fiat rails, launchpad, mobile apps and KYC vendor internals stay out, with KYC behind an interface.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Spot plus futures and margin | Closer to the product a large exchange sells | A second risk model with liquidations, mark prices and funding | Doubles the correctness surface without adding an availability property to design for |
| Spot with simulated balances and no custody | Removes the riskiest component | Deposits, withdrawals and keys never appear in the design | Problem 5 secures custody, so the design must contain it |
| Market data and order entry without settlement | Simplest to scale | No ledger, so REQ-P1-14A cannot be shown | Not a trading system in the sense of REQ-P1-1 |

## Trade-offs

The cut works against breadth of REQ-P1-1 to keep depth on REQ-P1-14A. KYC behind an interface defers the compliance controls that FSI-DP3 asks to design in, and Problem 5 makes AML onboarding a launch gate (SC-14) to close that gap.

## Consequences

### Positive

- Every in-scope feature has a protocol, a failure row or a test in `SOLUTION.md`.
- Bounded contexts for trading, wallet and identity give teams clear ownership (OPS-DP1).

### Negative

- Users who expect derivatives or fiat on-ramps do not find them at launch.

### Risks

- A later derivatives product needs margin across positions, which the per-account reservation model of ADR-P1-0004 does not cover. The scaling plan treats it as a new risk model, not an extension.

## Verification

Review: each in-scope feature maps to section 3.3, section 4 or section 6 of `SOLUTION.md`, and each excluded feature appears in section 14 with its reason (review).

## Reopen when

The product roadmap dates a derivatives, margin or fiat product, or the number of spot pairs exceeds what the stage 0 matching pool carries in the AD-P1-20 benchmark.
