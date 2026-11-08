# D11 — RWA Tokenization Platform

Base Sepolia release: seven deployed contracts are Sourcify exact-match verified. The [three-role synthetic issuance, transfer and redemption workflow](docs/deployment/base-public-acceptance.md) passed on-chain. [Actual addresses, receipts and role checks](deployments/base-sepolia-20261108.json). Ethereum Sepolia compatibility and hosted acceptance remain separate gates.
[Current self-assessment and release gates](docs/audit/review-2026-11-08.md) · [WSL source policy](docs/deployment/workspace-workflow.md)
A local, fully simulated platform for permissioned bond-style units: identity eligibility,
jurisdiction policy, holding limits, dual-party issuance, reserved redemption with
reviewer-confirmed synthetic payment receipts, and an offchain holder-register reconciliation.
Everything runs against a disposable Anvil chain; no real assets, money, or legal instruments
are involved.

## Quick start

Use Ubuntu-24.04 WSL with Foundry 1.8.1 and solc 0.8.24 (both pinned).

```bash
forge test                              # 48 checks: 46 unit/fuzz + 2 invariant suites
bash scripts/institutional-smoke.sh     # end-to-end local business workflow
bash scripts/verify-critical-paths.sh   # Halmos + Echidna critical properties
bash scripts/ops-demo.sh                # browser-driven operations demo (see below)
```

## What is verified, and where the evidence lives

| Claim | How to reproduce | Evidence |
| --- | --- | --- |
| 48 Foundry tests PASS (1024-run fuzz, 2 invariant suites @128 runs / 8192 calls / 0 reverts) | `forge test` | `evidence/forge-test.txt` |
| Multi-party redemption invariants: reservations always backed by balances; supply decreases only by settled or voluntarily burned units | `forge test --match-contract RedemptionInvariant -vv` | suite output |
| Halmos symbolic checks: exact-burn settlement, settlement replay, cross-holder payment replay, unauthorized confirm (4 properties, 43 paths) | `FOUNDRY_DYNAMIC_TEST_LINKING=false FOUNDRY_OUT=out-halmos halmos --contract RedemptionSymbolic --forge-build-out out-halmos` | `evidence/halmos-redemption.txt` |
| Halmos issuer self-execution rejection | `bash scripts/verify-critical-paths.sh` | `evidence/halmos-static-link.txt` |
| Echidna lifecycle supply accounting (20000 calls, seed 10) | `bash scripts/verify-critical-paths.sh` | `evidence/echidna-solc.txt` |
| Dual approval, wrong-amount receipt rejection, 30-unit settlement, payment replay rejection, unpaid release, register reconciliation | `bash scripts/institutional-smoke.sh` | `evidence/redemption-business.txt` |
| Browser operations demo: dual issuance, transfer, reservation lock, settlement, replay rejection, final ledger reconciled | `bash scripts/ops-demo.sh` | `evidence/ops-demo.txt` |
| Slither / Aderyn triage (all alerts dispositioned, none exploitable) | `slither . --filter-paths lib`, `aderyn .` | `evidence/slither-current.txt`, `evidence/aderyn-current.md`, [review](docs/audit/independent-review-2026-11-05.md) |

Historical reports in `evidence/` are kept untouched; each rerun overwrites only its own
`*-current` / dated file.

## Operations console (browser demo)

`apps/web` is a Next.js 15 console that drives the full lifecycle through real transactions on a
disposable Anvil chain using unlocked local accounts:

1. Attest identity (issuer) → 2. Propose issuance (issuer) → 3. Execute issuance (independent
   reviewer; issuer self-execution is rejected onchain) → 4. Transfer (holder, restricted by
   reservations) → 5. Request redemption (holder, units become reserved) → 6. Approve (issuer) →
   7. Settle with synthetic receipt (reviewer; the browser computes the same SHA-256 payment and
   receipt digests as `scripts/check-redemption-receipt.py`) → 8. Replay attempts revert.

`bash scripts/ops-demo.sh` starts Anvil on port 18673, deploys, serves the production build on
port 18731, drives a headless Chromium through the flow, asserts every onchain receipt status,
and reconciles the final holder register with `scripts/reconcile-register.py`. Requirements:
Foundry, python3, jq, Node 22, a Playwright module (`PLAYWRIGHT_MODULE`) and a Chromium
executable (`CHROME_EXECUTABLE`). The demo redirects the page's RPC (port 8545) to the isolated
chain, so nothing else on the machine is touched.

## Architecture

```
IdentityRegistry ── eligibility ──► ComplianceEngine ──► PermissionedToken (cap, freeze, pause, reserve)
                                                              ▲ onlyManager
InstitutionalApproval ── owns ──► IssuanceManager ── mint/burn/reserve/release
   issuer proposes/approves           reviewer executes/settles
CorporateActions: simulated distribution acknowledgements (no funds move)
```

- Issuance requires two distinct keys: the issuer proposes, an immutable independent reviewer
  executes. The reviewer cannot propose; the issuer cannot execute.
- Redemption is a state machine `Missing → Pending → Approved → Settled`, with `Cancelled` from
  `Pending` (holder) or from `Approved` (reviewer rejects an unpaid request, releasing the
  reservation). Reserved units cannot be transferred or voluntarily burned.
- Settlement burns exactly the request's units. Payment and receipt digests have global replay
  protection per manager; the digest content is validated offchain
  (`scripts/check-redemption-receipt.py` binds chain id, manager, holder, reference, units and
  amount — this binding is **not** enforced onchain, see F-02 in the review).

## Security model and trust boundaries

Read the full independent review: [docs/audit/independent-review-2026-11-05.md](docs/audit/independent-review-2026-11-05.md)
(AI-assisted self-assessment, **not** a third-party audit). Accepted residual risks:

- **F-01**: owner and reviewer are immutable EOAs with no rotation or recovery.
- **F-02**: payment receipt authenticity is enforced by the reviewer's offchain validation only;
  the contract accepts any unique non-zero digests.
- **F-03**: payment/receipt digests are replay-protected per deployment but not bound to chain or
  contract address onchain.
- **F-06**: an expired identity blocks the holder's own transfers but not manager-driven
  settlement (intentional exit path).

Tokens do not convey legal title. Identity evidence is represented only by hashes; never store
personal information onchain. This project is *inspired by* ERC-3643 mechanics (permissioned
transfers, identity gating, freeze) but implements only the subset listed above — it has no
ONCHAINID claims/verified-claims registry, no recovery, no forced transfers and no batch
operations, and makes no compliance claim beyond the implemented and tested interfaces.

## Testing strategy

- Unit/fuzz: 46 tests, 1024 fuzz runs (`foundry.toml`, CI profile raises to 10000).
- Stateful invariants: supply conservation under transfers; multi-party redemption accounting
  (`test/Invariant.t.sol`, `test/RedemptionInvariant.t.sol`).
- Symbolic: Halmos over the issuance-approval boundary and the redemption state machine
  (`test/ApprovalSymbolic.t.sol`, `test/RedemptionSymbolic.t.sol`).
- Property-based: Echidna lifecycle accounting (`audit/LifecycleFuzz.sol`).
- Business workflow: `scripts/institutional-smoke.sh` covers correct payment, wrong amount,
  duplicate receipt, unpaid release, cross-request payment replay and final register
  reconciliation; `scripts/ops-demo.sh` repeats the core lifecycle through a real browser.

## CI

`.github/workflows/ci.yml` runs format check, build with sizes, CI-profile tests, coverage, the
business smoke and the web build on `ubuntu-24.04`, and archives evidence artifacts.
Status: configured and locally mirrored; remote execution has not been run from this workspace.

## Repository map

- Contracts: `src/Platform.sol`, `src/InstitutionalApproval.sol`, `src/CorporateActions.sol`
- Tests: `test/`, Echidna harness in `audit/`
- Ops scripts: `scripts/` (smoke, receipt validation, register reconciliation, critical paths)
- Reviews: [independent review](docs/audit/independent-review-2026-11-05.md),
  [institutional review](docs/audit/institutional-review.md),
  [redemption review](docs/audit/redemption-review.md)
- Economics: [model](docs/economics/economic-model.md), [invariants](docs/economics/invariants.md),
  [attack scenarios](docs/economics/attack-scenarios.md)
- [Architecture](docs/architecture/design.md), [ADR 001](docs/adr/001-permissioned-simulation.md),
  [handoff log](HANDOFF.md)

## Engineering Quality Gate (honest status)

| Item | Status | Evidence / note |
| --- | --- | --- |
| Industrial code & explicit Foundry config | PASS | `foundry.toml` pinned solc 0.8.38 |
| Compile & tests pass | PASS | 48 Solidity tests; 5 frontend tests; dated review evidence |
| Branch coverage ≥90% on core source | PASS | Platform 92.11%, InstitutionalApproval 100%, CorporateActions 100% branches; `evidence/coverage.txt` |
| Fuzz/invariant verification | PASS | 2 campaigns, 0 reverts |
| Static + manual review with PoC triage | PASS | Slither/Aderyn dispositioned in review doc |
| Economic security gate | PASS (simulation scope) | `docs/economics/` |
| Reproducible build | PASS | pinned toolchain, lockfiles |
| Local deployment | PASS | smoke scripts deploy fresh each run |
| Public testnet deployment | PASS (Base Sepolia) | seven exact-match verified contracts; ten workflow transactions, five rejection checks; Ethereum Sepolia compatibility BLOCKED |
| Frontend demo | PASS (local) | `scripts/ops-demo.sh` |
| Dependency audit | BLOCKED | npm registry unreachable from this network (mirror 404 / ECONNRESET) |
| README & docs | PASS | this file |

## Learning Mastery Gate

Self-reported by the operator; this repository alone is not evidence of mastery. Marked NOT RUN
pending the walkthrough exercises in `docs/learning/` and `docs/code-walkthrough/`.

## Attribution

Code and documentation were produced with AI assistance under human direction; the independent
review above is likewise AI-assisted. Foundry supplies compiler/testing/Anvil infrastructure.
Nothing here is an independent security audit or a certification.
