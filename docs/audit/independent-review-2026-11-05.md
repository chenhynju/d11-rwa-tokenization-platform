# Independent Review — 2026-11-05 (AI-assisted self-assessment)

This review was performed by an AI engineer **independent of the original development process**.
It is not a third-party security audit and makes no certification claim.

## Scope freeze

- Git state: repository on branch `master` with **zero commits**; all files untracked.
  A hash baseline was recorded instead of a commit SHA: `evidence/audit-baseline-2026-11-05.txt`
  (SHA-256 of `src/`, `test/`, `script/`, `audit/`, `scripts/`, `foundry.toml`, `.github/`).
- Compiler: solc 0.8.24 (pinned via `foundry.toml`), EVM `cancun`, `via_ir`, optimizer 1000.
- Toolchain verified live: forge 1.8.1, Slither 0.11.6, Aderyn 0.6.8, Echidna 2.3.3, Halmos 0.3.3.
- In scope: `src/Platform.sol`, `src/InstitutionalApproval.sol`, `src/CorporateActions.sol`,
  `script/Deploy.s.sol`, `scripts/*.sh`, `scripts/*.py`, `test/*`, `audit/LifecycleFuzz.sol`.
- Out of scope: frontend (`apps/web`) reviewed for build/runtime evidence only; `lib/` dependencies.
- Trusted roles: platform owner/issuer (immutable deployer EOA), independent reviewer (immutable EOA),
  identity registry owner, compliance owner. All trust is documented below.

## Re-executed evidence (this review, not historical claims)

| Check | Command | Result |
| --- | --- | --- |
| Unit/fuzz/invariant | `forge test` | 45/45 PASS (44 unit+fuzz @1024 runs, 1 invariant @128 runs/8192 calls/0 reverts) |
| Business smoke | `bash scripts/institutional-smoke.sh` | PASS (dual approval, wrong-amount receipt rejected, 30-unit settlement, replay rejected, unpaid release, register reconciled) |
| Slither | `slither . --filter-paths lib` | 10 results, all triaged below |
| Aderyn | `aderyn .` | 1 high, 7 low categories, all triaged below |
| Halmos | `scripts/verify-critical-paths.sh` | 1 symbolic property, 4 paths, PASS (pre-existing run confirmed fresh) |
| Echidna | `scripts/verify-critical-paths.sh` | `echidna_supply_accounting` passing @20000 calls seed 10 |

## Tool alert triage

### Aderyn H-1: "State change after external call" in `PermissionedToken.mint` (line 184) and `reserve` (line 196) — NOT EXPLOITABLE (false positive, accepted)

Root cause of the flag: the `require(...)` performs an external `STATICCALL` to `compliance`
(`ComplianceEngine.eligible` / `canReceive`) before `totalSupply` / `balanceOf` / `reserved` are updated.

Why it is not exploitable here:

1. `compliance` is `immutable`, bound in the constructor to a concrete `ComplianceEngine`
   deployed in the same atomic transaction bundle (see `script/Deploy.s.sol`). It cannot be
   rebound or upgraded.
2. The called functions are `view`; the EVM executes them as `STATICCALL`, so the callee cannot
   modify state and cannot re-enter with effects.
3. `ComplianceEngine.eligible` performs one further static call to the immutable
   `IdentityRegistry`, also `view`. Neither contract contains any external call that could
   reach back into the token.

Residual risk: the safety argument rests on the deployment binding these exact contracts.
If `compliance` were ever bound to a malicious or upgradeable contract, the flag would become
real. This trust assumption is now explicit in the README trust model.

### Slither reentrancy-events (7 findings) — INFORMATIONAL

All seven flag events emitted after external calls (`issue`, `redeem`, `requestRedemption`,
`cancelRedemption`, `approveRedemption` path, `confirmRedemption`, `rejectUnpaidRedemption`,
`InstitutionalApproval.execute`). In every function all state writes (`processed`, `redeemed`,
`status`, `usedPayments`, `usedReceipts`) happen **before** the external call; only the event
follows. The callees are the immutable trusted token/manager pair. No state inconsistency can
result. Accepted as informational.

### Slither timestamp (3 findings) — ACCEPTED

`block.timestamp` is used only for identity expiry and asset maturity comparisons, which is the
intended business semantic; miner manipulation over the relevant horizons is immaterial.

### Aderyn L-1..L-7 — TRIAGED

- L-1 Centralization: acknowledged; see F-01/F-02.
- L-2 Empty `require()`: style; several boundary `require` statements lack messages. Accepted (bytecode-size trade-off), listed as future polish.
- L-3 PUSH0: target is `cancun`; fine.
- L-4 State change without event: **actionable** — fixed as F-04 (`reserve`/`release`/`close` now emit events).
- L-5 Address set without checks: `bindManager` requires `target.code.length > 0` and is one-shot; accepted.
- L-6 Floating pragma `^0.8.24`: the toolchain pins solc 0.8.24 in `foundry.toml`; accepted, noted for hardening.
- L-7 Public function not used internally: style; accepted.

## Manual findings

### F-01 (Medium, accepted/design): Immutable privileged keys, no recovery

`Controlled.owner`, `InstitutionalApproval.reviewer` and the created `IssuanceManager` owner are
all immutable EOAs set at construction. Loss of the reviewer key permanently blocks all
settlements; a compromised reviewer key can settle with fabricated receipts (see F-02); loss of
the issuer key freezes issuance/approval forever. There is no rotation, timelock, or two-step
transfer.

- **Affected**: `src/Platform.sol:4-15`, `src/InstitutionalApproval.sol:21-25`
- **Recommendation**: for anything beyond simulation, use `Ownable2Step` and a rotatable
  reviewer role (e.g. `AccessControl` with a `REVIEWER_ROLE` plus timelocked rotation).
- **Status**: accepted residual risk for a local simulation; documented in README trust model.

### F-02 (Medium, accepted/design): Receipt authenticity is enforced offchain only

`confirmRedemption(holder, ref, payment, receipt)` accepts any non-zero unique digests. The
contract cannot verify that `receipt` commits to the chain, manager, holder, reference, units and
amount. The binding is computed offchain by `scripts/check-redemption-receipt.py` (SHA-256 over a
canonical JSON containing exactly those fields) and is enforced only by the reviewer's diligence.

- **Affected**: `src/Platform.sol:298-313`
- **Mitigations in place**: reviewer is a separate key from the issuer (two-party control);
  global `usedPayments`/`usedReceipts` replay protection; wrong-amount receipt is rejected by the
  offchain validator and demonstrated in the smoke test.
- **Recommendation**: a production system would settle against a verifiable payment rail
  (onchain escrow/stablecoin, or signed attestation verified onchain).
- **Status**: accepted as the stated simulation boundary; evidence of both acceptance items
  (reviewer confirmation path AND offchain payment validation) is recorded in
  `evidence/institutional-smoke.txt` / latest smoke rerun.

### F-03 (Low, documented): Payment/receipt digests are not bound to chain or contract onchain

`usedPayments` / `usedReceipts` are per-`IssuanceManager` storage. The same digest could be
reused on a different deployment of the platform. Offchain, `check-redemption-receipt.py`
enforces `chainId == 31337` and the exact manager address, so within the validated workflow the
digest does bind chain and contract; but a caller bypassing the validator is not constrained
onchain. For multi-deployment production use, bind `block.chainid` and `address(this)` into the
digest onchain. Accepted for single-deployment local simulation.

### F-04 (Low, FIXED in this review): Missing events on reservation lifecycle

`PermissionedToken.reserve`, `release` and `CorporateActions.close` changed state without events,
breaking the "important state changes are auditable" requirement (also Aderyn L-4). Fixed by
adding `Reserved`, `Released` and `Closed` events. Regression: full forge suite + smoke rerun.

### F-05 (Low, documented): Cancelled redemption reference cannot be reused

After `cancelRedemption` or `rejectUnpaidRedemption`, the reference stays in `Cancelled` status
forever; a holder must pick a new reference to retry. This is a deliberate idempotency choice
(references are one-shot across the whole lifecycle), now documented. Retry after a **failed**
(reverted) settlement is unaffected: the request remains `Approved` and can be reconfirmed with a
corrected receipt.

### F-06 (Informational, documented): Identity expiry locks transfers but not settlement

`checkTransfer` requires `compliance.eligible(from)`, so an expired identity blocks the holder's
own transfers while leaving manager-driven `release`/`burn` operable. Reserved redemptions can
therefore still settle after expiry (funds leave through the issuer), but the holder cannot move
units. This asymmetry is intentional (redemption is an exit path) and is now documented.

## Property verification status

| # | Property | Status |
| --- | --- | --- |
| P1 | `reserved[holder] <= balanceOf[holder]`; transfers and voluntary burns cannot spend reserved units | Verified by `testRedemptionReservationsRemainBackedAcrossSettlement`, smoke step (`redeem` of 71 with 30 reserved rejected), and the new multi-party invariant `RedemptionInvariant` |
| P2 | Each successful settlement burns exactly that request's units; repeated/failed/unauthorized settlement cannot change supply, balances, or other requests' reservations | Verified by unit tests + smoke (replay rejected, no state change), and new Halmos checks `check_SettlementAccounting`, `check_SettlementReplay`, `check_UnauthorizedConfirm` |
| P3 | The same payment identifier cannot fund a second request, even with a different receipt digest, reference, or holder | Verified by smoke cross-request replay rejection and new Halmos `check_PaymentReplayAcrossHolders` |

## Fix verification (post-review regression, same day)

- F-04 fixed: `Reserved`/`Released`/`Closed` events added; Aderyn rerun no longer reports
  "State Change Without Event" (see `evidence/aderyn-current.md`).
- Full suite rerun after the fix and the new tests: **48/48 PASS**
  (46 unit/fuzz + 2 invariant suites), `evidence/forge-test.txt`.
- New coverage: Platform branches 92.11% (35/38), InstitutionalApproval 100% (7/7),
  CorporateActions 100% (8/8); `evidence/coverage.txt`. The two new unit tests
  (`testRedemptionRequestBoundaries`, `testInstitutionalRedemptionProxies`) closed the
  InstitutionalApproval proxy gap found during this review.
- Business smoke, Halmos (approval + redemption), Echidna and Slither rerun clean after all
  changes; browser operations demo passed with 8 confirmed receipts and a reconciled register
  (`evidence/ops-demo.txt`).

Coverage boundaries of the symbolic checks: amounts bounded to `0 < units <= 500`, references and
digests are symbolic 256-bit values, `msg.sender` alternation modeled with concrete helper
contracts. Paths not covered: interactions with `pause`/`freeze` during settlement, and symbolic
identity expiry. These are exercised by concrete unit tests instead.
