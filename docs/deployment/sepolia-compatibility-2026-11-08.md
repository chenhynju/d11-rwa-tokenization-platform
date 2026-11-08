# Sepolia deployment compatibility checkpoint

Status: **BLOCKED**. A local deployment simulation succeeded, but the first real creation transaction failed and used its entire 608,934 gas allowance. The receipt is retained in [the failure record](../../deployments/sepolia-failed-20261108.json). No successful deployment address is claimed.

The current toolchain is Foundry 1.8.1 (2026-08-28), with a Cancun execution configuration. The [Ethereum Foundation activation announcement](https://blog.ethereum.org/2026/09/17/glamsterdam-testnet-announcement) schedules Glamsterdam on Sepolia for 2026-10-06. Its [repricing guidance](https://blog.ethereum.org/2026/08/24/glamsterdam-repricing-testing) warns that cached state-creation gas assumptions can underestimate deployment costs. This is a plausible compatibility explanation, not a trace-proven root cause. A compatible RPC estimator and execution model must be checked before any new deployment plan. The failed transaction consumed nonce6; the observed pending nonce is7. Do not resume a stale plan that predicts contract addresses from nonce6.

All nine original planned transactions, the signed first transaction, chain queries and the real receipt remain in local evidence. Signing keys/passwords are excluded from Git. Source verification and public business smoke tests are NOT RUN.
