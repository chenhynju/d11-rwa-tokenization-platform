# Public testnet release and operator workflow

AI-Assisted Self-Assessment and teaching material. Learning Mastery is NOT RUN.

The contracts were deployed from source commit3f236462e888e52dda3d971b86a7b0e274fd9098. The operator source below is bound by SHA256 in the actual local execution record; gitHeadAtRun records the repository HEAD at execution and may precede the evidence commit.

## Requirement and design
Demonstrate synthetic issuance, transfer and redemption with three distinct addresses. No legal title, offchain reserves, real payment settlement or independent human custody is established.

## Source and execution
[scripts/public_testnet_smoke.py](../../scripts/public_testnet_smoke.py) verifies the RPC chain, runtime hashes and signer identities before any signing. Public execution accepts Base Sepolia84532 only. Unlocked signing requires explicit loopback Anvil31337. Mainnet is rejected. A per-issuer process lock serializes operators. Every signed transaction has a persisted, atomically replaced and fsynced intent with an explicit nonce; uncertain submission stops without automatic replacement. A resumed run validates successful receipts rather than signing again. The frozen workflow source hash must remain unchanged.

## State and mathematics
The issuer attests the holder and transfer recipient, then proposes400 units. The reviewer executes issuance. The holder transfers150 units and reserves200 for redemption. The issuer approves; a reviewer-confirmed SIM receipt burns200. Final holder balance is400-150-200=50, recipient balance150, reserved0 and supply400-200=200. Python integer arithmetic and an exact100 minor units per synthetic unit avoid floating-point settlement errors. The receipt validator checks chain, holder, manager, reference, approved state, integer types, currency and amount before hashing canonical JSON. It is a simulation policy, not evidence of a real bank payment.

## Security and alternatives
Calls must reject issuer self-approval, spending reserved shares, cancellation after approval, issuer payment confirmation and payment replay. Every recorded receipt must succeed before acceptance, even if balances appear settled. Initial execution refuses an existing nonempty market; earlier user state is preserved. Automatic retry after an ambiguous broadcast is deliberately excluded in favor of explicit reconciliation.

## Tests and evidence
[scripts/test_public_workflow.py](../../scripts/test_public_workflow.py) creates an owned disposable node and exercises ten real local transactions plus five rejection checks. It proves unchanged nonces on rerun, preservation of an existing market and refusal of an injected unresolved confirmation. [Receipt policy regressions](../../scripts/test_receipt_policy.py) cover seven chain/currency/state/type boundaries. Base contract deployment, runtime, roles and Sourcify exact matches are recorded in [the actual deployment evidence](../../deployments/base-sepolia-20261108.json). Public operator acceptance is recorded separately after actual execution; local results are not public-network proof.

## Interview defense
Explain why a successful outer receipt cannot alone prove business success; why an intent nonce does not establish exactly-once completion; how reserving shares differs from burning them; why trusted reviewer hashes do not prove offchain solvency; and why three addresses are not proof of three independent people.

Current operator SHA256: `5963a5978a8a4fd78009b66234510cb99bcd9d2559968f043838fa2ea41121e7`. Latest bound local proof: [20261108T160150660469Z](../../evidence/local-workflow/20261108T160150660469Z/acceptance.json).
