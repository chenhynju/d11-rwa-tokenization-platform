#!/usr/bin/env bash
# Browser-driven operations demo on a disposable Anvil chain.
# Requires: forge, cast, anvil, jq, python3, node (with apps/web built), playwright
# (PLAYWRIGHT_MODULE) and a Chromium executable (CHROME_EXECUTABLE).
set -euo pipefail
cd "$(dirname "$0")/.."
export ETH_RPC_URL=http://127.0.0.1:18673
port=18673
webport=18731
if ss -lntH | awk '{print $4}' | grep -Eq ":(${port}|${webport})$"; then echo "Port occupied"; exit 1; fi
anvil --port "$port" --silent >/dev/null 2>&1 &
anvil_pid=$!
web_pid=""
register=""
cleanup() {
  [[ -n $register ]] && rm -f "$register"
  [[ -n $web_pid ]] && kill "$web_pid" 2>/dev/null || true
  kill "$anvil_pid" 2>/dev/null || true
}
trap cleanup EXIT
for i in {1..40}; do cast chain-id >/dev/null 2>&1 && break; sleep .2; done
kill -0 "$anvil_pid"
test "$(cast chain-id)" = 31337
accounts=$(cast rpc eth_accounts)
issuer=$(jq -r '.[0]' <<<"$accounts")
holder=$(jq -r '.[2]' <<<"$accounts")
holder2=$(jq -r '.[3]' <<<"$accounts")
export LOCAL_REVIEWER=$(jq -r '.[1]' <<<"$accounts")
forge script script/Deploy.s.sol:Deploy --rpc-url "$ETH_RPC_URL" --sender "$issuer" --unlocked --broadcast >/dev/null
contract() { jq -r --arg n "$1" '.transactions[]|select(.transactionType=="CREATE" and .contractName==$n)|.contractAddress' broadcast/Deploy.s.sol/31337/run-latest.json; }
approval=$(contract InstitutionalApproval)
token=$(contract PermissionedToken)
ids=$(contract IdentityRegistry)
(cd apps/web && exec node node_modules/next/dist/bin/next start --hostname 127.0.0.1 --port "$webport" >/dev/null 2>&1) &
web_pid=$!
ready=0
for i in {1..90}; do curl -sf "http://127.0.0.1:$webport" >/dev/null 2>&1 && { ready=1; break; }; sleep .5; done
test "$ready" = 1
node scripts/ops-smoke.cjs "$token" "$approval" "$ids"
register=$(mktemp)
printf 'address,units\n%s,50\n%s,150\n' "$holder" "$holder2" > "$register"
python3 scripts/reconcile-register.py "$token" "$register"
echo 'PASS ops demo: browser ledger reconciled with onchain register'
