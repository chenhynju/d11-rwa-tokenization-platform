# Institutional deployment review — AI-assisted self-assessment

Scope covers the local Deploy script, InstitutionalApproval, IssuanceManager, PermissionedToken and their concrete identity and compliance dependencies. The chain guard requires chain 31337.

## W10-01 — issuer could bypass independent approval in the default deployment

The previous deployment constructed IssuanceManager directly. Its immutable owner was the deployment signer, so a single issuer could call issue without creating or approving a request. The approval module's unit tests used a different configuration. Impact was unauthorized issuance under the intended two-person policy, within per-wallet and supply caps.

Deploy now constructs InstitutionalApproval, reads the independent reviewer address from LOCAL_REVIEWER, and binds the manager created by that controller. The controller constructor rejects the zero address and the issuer address. Separate addresses still rely on organizational separation of key custody. Existing immutable deployments require a fresh deployment to adopt the change.

Run bash scripts/institutional-smoke.sh from the Foundry root. It starts disposable Anvil, deploys through the normal script, attests a holder, proposes 100 units, checks issuer execution fails, sends reviewer execution and checks holder balance. The caller restriction is additionally exercised by testIndependentApproval, including direct manager bypass.

## Static findings

Aderyn H-1 flags writes after the eligibility check during mint. The concrete compliance method is view and Solidity emits STATICCALL. The static context propagates to nested calls, so state writes cannot occur during that check. There is no receiver callback. This specific trace provides no state-changing reentry path. Reassess if compliance calls or token hooks change.

Slither's three reentrancy-events reports concern execute, issue and redeem. Each records its replay guard before the external call. The bound manager/token pair is fixed after deployment. Mint checks eligibility through view calls and burn has no external call. Inner transfer events precede the outer business event by design and a revert removes all logs. Indexers must order by block, transaction index and log index.

The three timestamp reports concern expiry and maturity. Expiry is exclusive at the recorded second and uses block time. Issuers must avoid relying on exact wall-clock transaction inclusion. Registration checks a future maturity but does not automate settlement on that date.

Low observations include centralized administrative authority, empty revert reasons, PUSH0 network compatibility, missing close event and constructor address validation. These are retained in the raw Aderyn report. Malconfigured dependencies, offchain custody, multi-wallet limits, payment confirmation and administrator compromise remain material boundaries. This assessment does not authorize public deployment.
