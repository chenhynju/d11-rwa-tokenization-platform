#!/usr/bin/env bash
# Run the bounded symbolic check and independent lifecycle fuzzer.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidence
command -v forge >/dev/null
command -v halmos >/dev/null
command -v echidna >/dev/null
test "$(halmos --version)" = 'halmos 0.3.3'
echidna --version | grep -F 'Echidna 2.3.3'
compiler="${SOLC_BINARY:-$HOME/.local/share/svm/0.8.38/solc-0.8.38}"
test -x "$compiler"
FOUNDRY_DYNAMIC_TEST_LINKING=false FOUNDRY_OUT=out-halmos   halmos --contract ApprovalSymbolic --forge-build-out out-halmos   > evidence/halmos-static-link.txt 2>&1
grep -F 'Symbolic test result: 1 passed; 0 failed' evidence/halmos-static-link.txt
echidna audit/LifecycleFuzz.sol --contract LifecycleFuzz   --test-limit 20000 --seed 10 --workers 1   --crytic-args="--compile-force-framework solc --solc $compiler"   > evidence/echidna-solc.txt 2>&1
grep -F 'echidna_supply_accounting: passing' evidence/echidna-solc.txt
