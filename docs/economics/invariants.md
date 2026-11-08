# Executable properties
- Supply equals sum of tracked holder balances during the two-holder transfer campaign: ConservationInvariant.invariantSupplyConservation.
- Supply remains 500 during transfer-only stateful testing; zero address never holds supply.
- Single transfers conserve supply: PlatformTest.testFuzzConservation, 1024 bounded random inputs.
- Failed delegated transfers preserve approval: testRejectedTransferKeepsAllowance.
- Duplicate issuance identifiers cannot mint twice: testDuplicateIssue.
- Distribution acknowledgement cannot repeat: testDistribution.

These tests are bounded evidence, not formal proofs. Current invariant handler only exercises transfers; mint/burn/rule/admin sequence invariants remain required.
