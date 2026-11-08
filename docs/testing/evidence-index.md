# Evidence Index — 2026-11-05 refresh

Two acceptance suites: **onchain contract tests** and **offchain business tests**.
Every item lists its rerun command and where output is archived. Statuses:
PASS / FAIL / BLOCKED / NOT RUN / N/A.

## A. Onchain contract tests

| # | Item | Status | Rerun | Log |
| --- | --- | --- | --- | --- |
| A1 | Unit + fuzz suite (46 tests, fuzz 1024 runs) | PASS | `forge test --match-contract PlatformTest` | `evidence/forge-test.txt` |
| A2 | Supply-conservation invariant (128 runs, depth 64, 8192 calls, 0 reverts) | PASS | `forge test --match-contract ConservationInvariant -vv` | `evidence/forge-test.txt` |
| A3 | Multi-party redemption invariants P1/P2 (reservations backed; supply decreases only by settled/voluntary burns; 128 runs, 8192 calls, 0 reverts) | PASS | `forge test --match-contract RedemptionInvariant -vv` | `evidence/forge-test.txt` |
| A4 | Halmos: issuer cannot self-execute (4 paths) | PASS | `bash scripts/verify-critical-paths.sh` | `evidence/halmos-static-link.txt` |
| A5 | Halmos redemption state machine: exact-burn settlement, settlement replay, cross-holder payment replay, unauthorized confirm (4 properties, 43 paths) | PASS | `FOUNDRY_DYNAMIC_TEST_LINKING=false FOUNDRY_OUT=out-halmos halmos --contract RedemptionSymbolic --forge-build-out out-halmos` | `evidence/halmos-redemption.txt` |
| A6 | Echidna lifecycle supply accounting (20000 calls, seed 10) | PASS | `bash scripts/verify-critical-paths.sh` | `evidence/echidna-solc.txt` |
| A7 | Slither static analysis — 10 results, all dispositioned (7 reentrancy-events informational, 3 timestamp accepted) | PASS | `slither . --filter-paths lib` | `evidence/slither-current.txt` |
| A8 | Aderyn static analysis — H-1 triaged as non-exploitable (immutable STATICCALL target), L-4 fixed via events | PASS | `aderyn .` | `evidence/aderyn-current.md` |
| A9 | Branch coverage core source ≥90% (Platform 92.11%, InstitutionalApproval 100%, CorporateActions 100%) | PASS | `forge coverage` | `evidence/coverage.txt` |
| A10 | Gas snapshot / build sizes | PASS | `forge snapshot`, `forge build --sizes` | `evidence/snapshot.txt`, `evidence/sizes.txt` |
| A11 | CI-profile deep fuzz (10000 runs, invariant 512/256) locally | NOT RUN this refresh | `FOUNDRY_PROFILE=ci forge test` | `evidence/ci-self-test.txt` (previous run) |
| A12 | Remote GitHub Actions execution | NOT RUN | push/PR trigger | `.github/workflows/ci.yml` |

## B. Offchain business tests

| # | Item | Status | Rerun | Log |
| --- | --- | --- | --- | --- |
| B1 | Institutional deployment; issuer self-execution rejected; reviewer executes 100-unit issuance | PASS | `bash scripts/institutional-smoke.sh` | `evidence/redemption-business.txt` |
| B2 | Correct synthetic payment receipt accepted; wrong amount (2999 vs 3000) rejected by offchain validator | PASS | same | same |
| B3 | 30-unit settlement burns exactly 30; supply/balance/reserved consistent | PASS | same | same |
| B4 | Payment replay across requests rejected onchain | PASS | same | same |
| B5 | Unpaid approved redemption rejected and reservation released | PASS | same | same |
| B6 | Final holder register reconciled at pinned block; mismatching register rejected | PASS | `python3 scripts/reconcile-register.py` (via smoke) | `evidence/register-reconciliation.txt` |
| B7 | Browser operations demo: attest → dual issuance (issuer self-execute rejected) → transfer → reservation lock (overspend reverts) → approve → reviewer settlement with browser-computed digests → replay rejected; ≥7 confirmed tx receipts; final register reconciled | PASS | `PLAYWRIGHT_MODULE=… CHROME_EXECUTABLE=… bash scripts/ops-demo.sh` | `evidence/ops-demo.txt` |
| B8 | Web production build | PASS | `node node_modules/next/dist/bin/next build` (in `apps/web`) | `evidence/web-build.txt` (previous); latest run in session log |
| B9 | npm dependency audit (`npm audit --audit-level=high`) | BLOCKED | `npm audit` in `apps/web` | registry mirror API 404 / official registry ECONNRESET; `evidence/npm-audit.json` |
| B10 | External payment authenticity (real payment rail) | N/A | — | simulation boundary, F-02 |

## Notes

- All runs use disposable Anvil chains (ports 18673 / 31337) with well-known test accounts.
- Reviewer receipt confirmation (onchain, B7/B3) and payment authenticity validation (offchain,
  B2) are separate acceptance items by design; both are evidenced independently.
- Coverage figures are source-only (deployment scripts excluded) per the handoff convention.
