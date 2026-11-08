import { test } from "node:test";
import assert from "node:assert/strict";
import { walletTransaction } from "../lib/connection.ts";
const actor = "0x1111111111111111111111111111111111111111" as const;
const other = "0x2222222222222222222222222222222222222222" as const;
function fixture(change?: "chain" | "account") {
  let chain = "0xaa36a7", account = actor as string;
  const sent: unknown[] = [];
  const provider = { async request({method, params}: {method:string;params?:unknown}) {
    if (method === "eth_chainId") return chain;
    if (method === "eth_accounts") return [account];
    if (method === "eth_estimateGas") { if (change === "chain") chain = "0x1"; if (change === "account") account = other; return "0x10000"; }
    if (method === "eth_sendTransaction") { sent.push(params); return "0xabc"; }
    throw new Error(method);
  }};
  return { provider, sent };
}
test("Sepolia writes bind sender, chain and estimated gas", async () => {
  const { provider, sent } = fixture();
  assert.equal(await walletTransaction(provider as never, actor, other, "0x", 11155111), "0xabc");
  assert.deepEqual(sent, [[{from:actor,to:other,data:"0x",chainId:"0xaa36a7",gas:"0x10000"}]]);
});
for (const changed of ["chain", "account"] as const) test(`wallet ${changed} change during gas estimation prevents submission`, async () => {
  const { provider, sent } = fixture(changed);
  await assert.rejects(walletTransaction(provider as never, actor, other, "0x", 11155111), /changed/);
  assert.equal(sent.length, 0);
});
