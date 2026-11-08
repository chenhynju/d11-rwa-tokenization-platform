# ADR 001: permissioned simulation
Context: demonstrate restricted bond-unit transfers without fabricating legal or custody integrations.
Decision: separate identity, policy and token lifecycle. Use indivisible units and document hashes. Enforce issuer cap and wallet cap on issuance. Exclude real-money payouts and pricing until settlement requirements exist.
Alternatives: permissionless ERC20; complete T-REX/ONCHAINID integration; stablecoin settlement vault.
Trade-offs: small reviewable prototype, but no ERC-3643 compliance claim or production financial product. Additional external calls increase transfer gas. Trusted issuer can change eligibility; no timelock or multisig exists yet.
