# Learning checks — mastery not assessed
1. Explain why token ownership cannot itself prove legal title. Answer: enforceable rights depend on instrument, issuer, custody, authoritative register and settlement arrangements.
2. Why does a rejected transferFrom preserve allowance? Answer: revert rolls back all writes in the transaction, including the earlier allowance decrement.
3. Why isolate cancellation and issuance IDs? Answer: holders control cancellation IDs and otherwise can consume an issuer's planned ID.
4. Can an allowlisted investor exceed a person-level cap using several wallets? Answer: yes; this implementation caps wallets, so a shared identity aggregate is required.
5. Does an 8192-call invariant run prove absence of bugs? Answer: no; the handler and bounded state space constrain the evidence.
6. Why does the approval controller own its manager? Answer: the manager constructor records the controller as owner, so direct issuer calls cannot bypass the reviewer.
7. Exercise: extend the invariant handler to issuance, revocation, freezing, policy changes and cancellation. Explain the expected conservation relation before coding.
8. Exercise: design an asynchronous redemption model that preserves investor claims until independently reconciled payment settlement; compare locking, escrow and cancellation.
