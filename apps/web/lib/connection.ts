import type { EIP1193Provider } from "viem";
export const expectedChainId = Number(process.env.NEXT_PUBLIC_RWA_CHAIN_ID ?? "31337");
if (![31337, 11155111, 84532].includes(expectedChainId)) throw new Error("Only Anvil, Ethereum Sepolia and Base Sepolia are supported");
export const rpcUrl = process.env.NEXT_PUBLIC_RWA_RPC_URL ?? (expectedChainId === 31337 ? "http://127.0.0.1:8545" : expectedChainId === 84532 ? "https://base-sepolia.gateway.tenderly.co" : "https://ethereum-sepolia-rpc.publicnode.com");
const endpoint = new URL(rpcUrl);
if (expectedChainId === 31337 && (endpoint.protocol !== "http:" || !["127.0.0.1", "localhost"].includes(endpoint.hostname))) throw new Error("Local unlocked accounts require a loopback RPC");
if (expectedChainId !== 31337 && (endpoint.protocol !== "https:" || endpoint.username || endpoint.password)) throw new Error("Public RPC must use HTTPS without embedded credentials");

function browserWallet(): EIP1193Provider {
  const provider = (window as unknown as { ethereum?: EIP1193Provider }).ethereum;
  if (!provider) throw new Error("Install an injected wallet to use the Sepolia demo");
  return provider;
}
export async function rpc(method: string, params: unknown[]) {
  const response = await fetch(rpcUrl, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }) });
  if (!response.ok) throw new Error("RPC is unavailable");
  const result = await response.json();
  if (result.error) throw new Error(result.error.message);
  return result.result;
}
export async function connectionAccounts(): Promise<string[]> {
  if (Number(BigInt(await rpc("eth_chainId", []))) !== expectedChainId) throw new Error("RPC chain does not match the configured market");
  if (expectedChainId === 31337) return rpc("eth_accounts", []);
  const wallet = browserWallet();
  if (Number(BigInt(await wallet.request({ method: "eth_chainId" }))) !== expectedChainId) throw new Error(expectedChainId === 84532 ? "Switch your wallet to Base Sepolia" : "Switch your wallet to Ethereum Sepolia");
  return wallet.request({ method: "eth_requestAccounts" });
}
export async function assertWalletContext(provider: EIP1193Provider, actor: string, chainId: number) {
  const chain = await provider.request({ method: "eth_chainId" });
  const accounts = await provider.request({ method: "eth_accounts" });
  if (Number(BigInt(chain)) !== chainId || accounts[0]?.toLowerCase() !== actor.toLowerCase()) throw new Error("Wallet account or network changed; restart this operation");
}
export async function walletTransaction(provider: EIP1193Provider, actor: `0x${string}`, to: `0x${string}`, data: `0x${string}`, chainId: number) {
  await assertWalletContext(provider, actor, chainId);
  const tx = { from: actor, to, data, chainId: `0x${chainId.toString(16)}` as `0x${string}` };
  const gas = await provider.request({ method: "eth_estimateGas", params: [tx] });
  await assertWalletContext(provider, actor, chainId);
  return provider.request({ method: "eth_sendTransaction", params: [{ ...tx, gas }] });
}
export async function sendTransaction(actor: `0x${string}`, to: `0x${string}`, data: `0x${string}`) {
  if (Number(BigInt(await rpc("eth_chainId", []))) !== expectedChainId) throw new Error("RPC chain mismatch");
  const hash = expectedChainId === 31337
    ? await rpc("eth_sendTransaction", [{ from: actor, to, data, chainId: "0x7a69" }])
    : await walletTransaction(browserWallet(), actor, to, data, expectedChainId);
  for (let i = 0; i < 120; i++) {
    const receipt = await rpc("eth_getTransactionReceipt", [hash]);
    if (receipt) {
      if (receipt.status !== "0x1") throw new Error("Transaction reverted: " + hash);
      return { hash: hash as string, block: Number(BigInt(receipt.blockNumber)) };
    }
    await new Promise((resolve) => setTimeout(resolve, expectedChainId === 31337 ? 250 : 1000));
  }
  throw new Error("Submitted, confirmation pending; check explorer before retrying: " + hash);
}
