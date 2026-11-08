# Repeatable bounded security checks

Run scripts/verify-critical-paths.sh from Ubuntu with Foundry, Halmos 0.3.3 and Echidna 2.3.3 on PATH. SOLC_BINARY can select the pinned 0.8.24 executable. The script fails on missing tools, execution failure or absent success summaries. Halmos must disable Foundry dynamic linking to avoid unsupported deployCode cheatcodes. Echidna compiles directly with solc to avoid incompatible Foundry build-info parsing.

The symbolic scope fixes the reviewer and investor and explores arbitrary nonzero request references with amounts from 1 through 1000. It checks that issuer self-execution fails without minting. The lifecycle fuzzer explores issuance and cancellation by one holder, asserting issuance minus cancellation equals supply and holdings, bounded by the cap. Neither campaign covers asynchronous payment settlement.

The existing GitHub workflow runs Foundry and frontend checks. Symbolic/fuzz/security tools are locally executed, and remote security jobs remain pending tool provisioning and pinned action verification. Historical static reports contain explicit triage in docs/audit/institutional-review.md. No suppression baseline is silently applied.
