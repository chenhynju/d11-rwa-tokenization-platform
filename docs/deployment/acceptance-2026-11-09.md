# D11 RWA acceptance evidence

Evidence index prepared 2026-11-09. Repository inspected at `779f1867f182d99f6cbefecacbc7f830acfdcb48`. Individual reports and deployment manifests identify the source that was tested or deployed.

| Gate | Result |
| --- | --- |
| Local engineering | PASS within the tested scope |
| Security self-review | Recorded in [AI-Assisted Self-Assessment](../audit/review-2026-11-08.md) |
| Independent third-party audit | NOT RUN |
| Owner learning mastery | NOT RUN |

## Local verification

48 Solidity tests, five frontend tests, and seven simulated receipt-policy tests passed. Local role-separated browser and operator workflows passed. [Contract tests](../../evidence/review-2026-11-08/d11-final-contracts.log) and [browser log](../../evidence/review-2026-11-08/d11-browser-owned.log).

## Public testnet

Base Sepolia deployment and synthetic lifecycle PASS. Nine setup receipts, seven exact-match source verifications, ten operator transactions and five read-only rejections are recorded. Ethereum Sepolia creation FAIL, and that route remains BLOCKED. [Base deployment](../../deployments/base-sepolia-20261108.json), [public workflow](base-public-acceptance.md) and [Ethereum failure](../../deployments/sepolia-failed-20261108.json).

## Remaining scope

The Base run covered issuance, transfer, redemption and ledger reconciliation. Payment receipts used SIM. Independent human custody, real fiat settlement and mainnet acceptance are NOT RUN.
