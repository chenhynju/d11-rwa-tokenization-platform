# Redemption settlement review

AI-Assisted Self-Assessment. Scope: PermissionedToken, IssuanceManager, InstitutionalApproval and the synthetic receipt validator. Solidity 0.8.24, Cancun. Local Anvil only.

## State transitions and accounting

The holder requests a reservation and can cancel before issuer approval. Once approved, the independent reviewer either confirms a payment or attests that it was unpaid and releases the reservation. A payment should only be initiated after approval is final. A successful confirmation releases and burns exactly the requested units in one transaction. Ordinary transfers and immediate cancellation burns are bounded by balance minus reserved units. Release and burn revert atomically if either fails. Supply is unchanged by request, approval and rejection.

The simulation exchanges each whole unit for 100 SIM minor units. Integer arithmetic in the receipt validator is exact. The offchain validator matches chain, manager, holder, request, status, units and amount. It emits a deterministic payment key and a separate digest over the complete receipt. The manager rejects either reused key or reused digest. The test deliberately supplies a new digest with a reused payment key on another request. The reviewer must run the validator and verify that the payment ID came from an authentic ledger before signing in an operational integration.

## Threats and operating boundaries

- Approved requests cannot be cancelled by the holder while an external payment is in flight. Reviewer loss or unavailability can strand an approved reservation. Reviewer rotation and recovery are future operational work.
- A reviewer can attest arbitrary digests or incorrectly reject an already paid request. The chain authenticates the reviewer and enforces replay rules. External payment authenticity and funds availability depend on a payment provider and treasury, which the simulation does not connect.
- Request references are holder-scoped. Payment keys are unique per manager. A shared payment rail would need uniqueness and reconciliation across deployments as well.
- The token manager is fixed after binding. Token operations use concrete contracts without receiver hooks. Redemption state and replay guards are updated before manager-to-token calls. A failed token call rolls back these updates and emitted events.
- The existing direct redemption method is voluntary cancellation without payment. It cannot consume reserved units and never produces a settlement event.

Reproduce the local transaction flow with bash scripts/institutional-smoke.sh. The relevant Foundry regressions exercise concurrent reservations, transfer limits, cross-request replay and pre-approval cancellation. See evidence/redemption-business.txt and evidence/redemption-forge.txt. A frozen audit commit and independent external review remain open.

## Static analysis triage

Slither 0.11.6 reported seven event-order observations and three timestamp observations. The four new event-order observations are request, cancel, unpaid rejection and confirmation. Request calls reserve, which checks eligibility via a view call and changes only token reservation state. Cancel and rejection call release, which has no external call. Confirmation calls release and burn, neither of which dispatches to an untrusted callback. In all four paths, the manager writes the request status before token interaction. Settlement also marks both replay keys before interaction. The three existing timestamp uses are identity expiry and future asset maturity, reviewed in the institutional report.

Aderyn 0.6.8 flagged state writes after read-only eligibility calls in mint/reserve. Both calls use STATICCALL and the concrete policy contracts expose no callback. These traces do not provide state-changing reentry. Lower-severity operational and style observations remain visible in the raw report. Audit scope is identified by the source hashes in evidence/redemption-source.sha256. The checkout has no frozen audit commit.
