# AI-Assisted Self-Assessment — status

Not an independent audit. Scope: `src/Platform.sol`, `src/InstitutionalApproval.sol`,
`src/CorporateActions.sol`. Compiler 0.8.24, Cancun, optimizer 1000, viaIR. No git commit exists;
the audit baseline is hash-frozen in `evidence/audit-baseline-2026-11-05.txt`.

Current authoritative review: [independent-review-2026-11-05.md](independent-review-2026-11-05.md)
(AI-assisted review performed independently of the original development process), superseding the
preliminary notes that previously lived here. Resolved since the preliminary note: dual-party
issuance approval, asynchronous redemption with reviewer settlement, reservation accounting
invariants, symbolic checks of the settlement path, and the reserve/release event auditability gap.

Remaining known gaps: immutable owner/reviewer keys without recovery (F-01), offchain-only
receipt authenticity (F-02), per-deployment replay namespace (F-03), no ONCHAINID or complete
ERC-3643 interface (explicitly out of scope), npm dependency audit blocked by network. Public
testnet broadcast remains unauthorized. Never interpret passing tests as release approval.
