#!/usr/bin/env bash
set -euo pipefail
export ETH_RPC_URL=http://127.0.0.1:18673
port=18673
if cast chain-id >/dev/null 2>&1; then echo "Port occupied"; exit 1; fi
anvil --port "$port" --silent >/dev/null 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT
for i in {1..40}; do cast chain-id >/dev/null 2>&1 && break; sleep .2; done
kill -0 "$pid"
test "$(cast chain-id)" = 31337
accounts=$(cast rpc eth_accounts)
issuer=$(jq -r '.[0]' <<<"$accounts")
export LOCAL_REVIEWER=$(jq -r '.[1]' <<<"$accounts")
holder=$(jq -r '.[2]' <<<"$accounts")
forge script script/Deploy.s.sol:Deploy --rpc-url "$ETH_RPC_URL" --sender "$issuer" --unlocked --broadcast >/dev/null
contract(){ jq -r --arg n "$1" '.transactions[]|select(.transactionType=="CREATE" and .contractName==$n)|.contractAddress' broadcast/Deploy.s.sol/31337/run-latest.json; }
approval=$(contract InstitutionalApproval)
token=$(contract PermissionedToken)
ids=$(contract IdentityRegistry)
ref=$(cast keccak demo-request)
send(){ cast send --unlocked --from "$1" "${@:2}" --json | jq -e '.status=="0x1"' >/dev/null; }
send "$issuer" "$ids" 'attest(address,uint16,uint64,bytes32)' "$holder" 840 4102444800 "$ref"
send "$issuer" "$approval" 'propose(bytes32,address,uint256)' "$ref" "$holder" 100
if cast call --from "$issuer" "$approval" 'execute(bytes32)' "$ref" >/dev/null 2>&1; then exit 1; fi
send "$LOCAL_REVIEWER" "$approval" 'execute(bytes32)' "$ref"
test "$(cast call "$token" 'balanceOf(address)(uint256)' "$holder")" = 100
echo 'PASS institutional deployment, issuer rejected, independent reviewer approved, holder balance 100'
if [[ -n ${BROWSER_CHECK:-} ]]; then
  "$BROWSER_CHECK" "$token" "$holder"
fi
register=$(mktemp)
trap 'rm -f "$register"; kill "$pid" 2>/dev/null || true' EXIT
printf 'address,units\n%s,100\n' "$holder" > "$register"
python3 scripts/reconcile-register.py "$token" "$register"
printf 'address,units\n%s,99\n' "$holder" > "$register"
if python3 scripts/reconcile-register.py "$token" "$register"; then
  echo 'incorrect register accepted' >&2; exit 1
else
  test "$?" = 1
fi
echo 'PASS synthetic register match and mismatch'

manager=$(cast call "$approval" 'manager()(address)' | tr '[:upper:]' '[:lower:]')
redemption=$(cast keccak demo-redemption)
send "$holder" "$manager" 'requestRedemption(bytes32,uint256)' "$redemption" 30
test "$(cast call "$token" 'reserved(address)(uint256)' "$holder")" = 30
if cast call --from "$holder" "$manager" 'redeem(bytes32,uint256)' "$redemption" 71 >/dev/null 2>&1; then exit 1; fi
send "$issuer" "$approval" 'approveRedemption(address,bytes32)' "$holder" "$redemption"
if cast call --from "$holder" "$manager" 'cancelRedemption(bytes32)' "$redemption" >/dev/null 2>&1; then exit 1; fi
jq -n --arg manager "$manager" --arg holder "$holder" --arg reference "$redemption" \
  '{chainId:31337,$manager,$holder,$reference,units:30,minorAmount:2999,currency:"SIM",paymentId:"synthetic-001"}' > "$register"
if python3 scripts/check-redemption-receipt.py "$manager" "$register"; then exit 1; fi
jq '.minorAmount=3000' "$register" > "$register.correct"
mv "$register.correct" "$register"
receipt_result=$(python3 scripts/check-redemption-receipt.py "$manager" "$register")
read -r payment receipt <<<"$receipt_result"
if cast call --from "$issuer" "$approval" 'confirmRedemption(address,bytes32,bytes32,bytes32)' "$holder" "$redemption" "$payment" "$receipt" >/dev/null 2>&1; then exit 1; fi
send "$LOCAL_REVIEWER" "$approval" 'confirmRedemption(address,bytes32,bytes32,bytes32)' "$holder" "$redemption" "$payment" "$receipt"
test "$(cast call "$token" 'reserved(address)(uint256)' "$holder")" = 0
test "$(cast call "$token" 'totalSupply()(uint256)')" = 70
test "$(cast call "$token" 'balanceOf(address)(uint256)' "$holder")" = 70
if cast call --from "$LOCAL_REVIEWER" "$approval" 'confirmRedemption(address,bytes32,bytes32,bytes32)' "$holder" "$redemption" "$payment" "$receipt" >/dev/null 2>&1; then exit 1; fi
printf 'address,units\n%s,70\n' "$holder" > "$register"
python3 scripts/reconcile-register.py "$token" "$register"
echo 'PASS synthetic redemption: receipt amount check, reviewer confirmation, replay rejection, final register reconciled'

second=$(cast keccak second-redemption)
send "$holder" "$manager" 'requestRedemption(bytes32,uint256)' "$second" 10
send "$issuer" "$approval" 'approveRedemption(address,bytes32)' "$holder" "$second"
if cast call --from "$LOCAL_REVIEWER" "$approval" 'confirmRedemption(address,bytes32,bytes32,bytes32)' "$holder" "$second" "$payment" "$second" >/dev/null 2>&1; then exit 1; fi
send "$LOCAL_REVIEWER" "$approval" 'rejectUnpaidRedemption(address,bytes32)' "$holder" "$second"
test "$(cast call "$token" 'reserved(address)(uint256)' "$holder")" = 0
test "$(cast call "$token" 'totalSupply()(uint256)')" = 70
echo 'PASS cross-request payment replay rejected and unpaid reservation released'
