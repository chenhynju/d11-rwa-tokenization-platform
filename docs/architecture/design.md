# Architecture and trust model
The issuer creates an asset record tied to a document digest and token address. The identity authority records country, expiry and evidence digest. Compliance applies current identity validity, jurisdiction and per-wallet limits. PermissionedToken enforces these rules on transfers and issuance; IssuanceManager is the sole mint/burn entry point. CorporateActions records a manually reconciled, budget-limited simulated allocation.

Transfer: caller -> allowance (delegated only) -> pause/freeze/balance -> sender identity -> receiver identity/jurisdiction/cap -> balance updates -> Transfer event. Failed checks atomically revert allowance and balances.

The owner is fully trusted in this prototype. There is no independent KYC provider, custody service, oracle, cash settlement or legal enforceability. Wallet limits can be circumvented by multiple approved wallets belonging to the same person. Revocation prevents transfers but does not erase holdings. Redemption can burn expired/frozen holdings; this is an explicit prototype policy requiring review before production.
