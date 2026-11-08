# Simulated economics
Units are indivisible token units (decimals=0). Supply cap=10000 units; initial wallet holding limit=1000 units. No price, exchange rate, interest accrual, fee or onchain currency exists. A token burn records cancellation only; it does not prove cash redemption. Legal rights depend on external documents, issuer, custodian, register and redemption arrangements.

For each issuance q: S'=S+q and B_recipient'=B_recipient+q. For each transfer q: B_sender'=B_sender-q, B_receiver'=B_receiver+q, S'=S. For cancellation q: S'=S-q, B_holder'=B_holder-q. All arithmetic uses checked uint256 integers. No rounding applies.

A distribution budget D uses sum(entitlements)<=D; closure requires equality. Acknowledgement is a one-time record and creates no payment. Manual allocations require independent reconciliation; no automatic pro-rata snapshot entitlement is implemented.

Worst case: issuer misconduct or offchain asset default can cause total economic loss even when every onchain invariant holds. No solvency claim is made.

## Synthetic cash redemption

The simulation prices each whole unit at 100 SIM minor units, with no rounding, fees, external price or oracle. A reservation keeps the units in the holder's balance and in total supply. Free units equal balance minus reserved units. Settlement reduces balance and supply by the requested units and clears that request's reservation. Unpaid rejection restores free units with no change to supply.

A confirmed receipt records a reviewer attestation. Cash reserves and payment finality are outside the contract. An approved request can remain locked during a treasury shortfall or reviewer outage. For actual money, treasury funding checks, a durable idempotent payment journal and reviewer recovery are required.
