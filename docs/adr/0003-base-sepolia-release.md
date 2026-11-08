# ADR: Base Sepolia release while Ethereum gas compatibility is blocked

Status: Accepted for the synthetic testnet demo.

The user-authorized networks include Ethereum Sepolia and Base Sepolia. The first Ethereum deployment failed after exhausting gas. Measured RPC estimation exceeded the Cancun simulation; local Foundry1.8.1 and1.8.7 Amsterdam-labelled runs retained legacy gas metering. Functional success on those simulators does not establish current Ethereum gas compatibility.

Use Base Sepolia for the current public demonstration, retaining the failed Ethereum transaction, measured discrepancies and BLOCKED status. The Base-specific deployment entrypoint fails on every other chain. Both scripts share identical protocol construction and role separation. The browser verifies its configured RPC and wallet chain, binds the sending account/chain, and rejects a changed wallet context after gas estimation. Public RPCs require HTTPS and never use unlocked RPC accounts.

Alternatives: wait for validated Ethereum-compatible tooling/RPC estimation; or create a custom transaction sequencer. The latter adds signing and nonce recovery code to a bounded portfolio demo and is deferred. Arbitrarily increasing a gas multiplier is not accepted as compatibility proof.

Trade-offs: Base is an L2 with sequencer and bridge assumptions; testnet assets carry no legal rights or financial value. This deployment does not demonstrate Ethereum Sepolia compatibility or independently held institutional custody. Public receipts, bytecode and permissions must still be verified before hosting acceptance.
