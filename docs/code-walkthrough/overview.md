# Source walkthrough
## Identity and eligibility
IdentityRegistry.attest stores a country code, expiration timestamp (seconds) and opaque evidence hash. Only the immutable owner can attest/revoke. verified returns false at the exact expiration boundary. ComplianceEngine.eligible combines validity with a country allowlist. canReceive checks resulting units against the current wallet cap. This cap is per address, not per legal person.
## Token transitions
Transfer checks pause, both freeze flags, nonzero recipient, free balance and both parties' eligibility. A self-transfer checks the original balance rather than adding units twice. Delegated transfer first consumes allowance, but the EVM reverts allowance changes when eligibility fails. Maximum uint256 approval is deliberately treated as unlimited.
## Issuance and cancellation
Only the bound manager can mint or burn. Mint checks supply cap and eligibility. Issuance reference IDs are globally unique. Cancellation references are unique per holder and isolated from issuance references to prevent cancellation from consuming another issuance request. Cancellation only burns the caller's units and does not prove an offchain payment.
## Institutional workflow
InstitutionalApproval creates and owns a manager. The issuer proposes immutable parameters, an independent reviewer executes them once, and the issuer can cancel unexecuted requests. Failed mint reverts the execution flag. Bind this controller's manager to a fresh token; the original direct-manager deployment script remains a basic MVP demonstration.
## Corporate actions
Budget and individual integer entitlements are manually reconciled. Closure requires exact allocation of the budget. A holder acknowledges once. This is a simulated ledger, not a payment or automatic dividend snapshot.
## Debugging
Run forge test --match-test testRedemptionCannotConsumeIssuanceReference -vvvv to trace namespace isolation. Run forge test --match-test testIndependentApproval -vvvv to trace issuer/reviewer authority. The invariant campaign only varies transfers between two holders; do not infer full administrator/lifecycle safety.

## Follow the redemption transaction

In src/Platform.sol, requestRedemption records holder-scoped intent and reserves units. Balance remains unchanged because the holder retains the claim until settlement. Ordinary transfers and immediate burns use free units. In src/InstitutionalApproval.sol, the issuer approves payment and the independent reviewer confirms it. The receipt checker compares exact integer cash units with the request. Settlement consumes the stable payment key and full receipt digest, then releases and burns the reserved units atomically. An unpaid rejection releases only the reservation.

Run forge test --match-test testRedemptionReservationsRemainBackedAcrossSettlement -vvvv. Explain why settling one reservation cannot consume a second reservation, why the payment key is separate from the receipt digest, and why holder cancellation is blocked after approval.
