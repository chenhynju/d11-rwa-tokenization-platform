'use client';
import {useState} from 'react';
import {isAddress,parseAbi,encodeFunctionData,createPublicClient,http} from 'viem';

import { expectedChainId, rpcUrl as RPC, rpc, connectionAccounts, sendTransaction } from '../lib/connection';
import { receiptAmounts } from '../lib/receipt';
type Addr=`0x${string}`;
const tokenAbi=parseAbi([
 'function totalSupply() view returns(uint256)','function cap() view returns(uint256)',
 'function paused() view returns(bool)','function balanceOf(address) view returns(uint256)',
 'function frozen(address) view returns(bool)','function reserved(address) view returns(uint256)',
 'function transfer(address,uint256) returns(bool)']);
const idsAbi=parseAbi(['function attest(address,uint16,uint64,bytes32)']);
const approvalAbi=parseAbi([
 'function propose(bytes32,address,uint256)','function execute(bytes32)',
 'function approveRedemption(address,bytes32)','function confirmRedemption(address,bytes32,bytes32,bytes32)',
 'function rejectUnpaidRedemption(address,bytes32)','function manager() view returns(address)']);
const managerAbi=parseAbi([
 'function requestRedemption(bytes32,uint256)','function cancelRedemption(bytes32)',
 'function redemptions(address,bytes32) view returns(uint256 units,uint8 status,bytes32 receipt)']);

async function sendTx(from:string,to:string,data:`0x${string}`){
 return sendTransaction(from as `0x${string}`,to as `0x${string}`,data);
}
async function sha256hex(text:string){
 const buf=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text));
 return '0x'+[...new Uint8Array(buf)].map(b=>b.toString(16).padStart(2,'0')).join('');
}
function refFrom(text:string){
 return sha256hex('ref:'+text);
}

export default function Page(){
 const [accounts,setAccounts]=useState<string[]>([]);
 const [actor,setActor]=useState('');
 const [token,setToken]=useState('');
 const [approval,setApproval]=useState('');
 const [ids,setIds]=useState('');
 const [chain,setChain]=useState('');
 const [holder,setHolder]=useState('');
 const [refText,setRefText]=useState('demo-1');
 const [units,setUnits]=useState('0');
 const [target,setTarget]=useState('');
 const [amount,setAmount]=useState('0');
 const [paymentId,setPaymentId]=useState('synthetic-001');
 const [ledger,setLedger]=useState('');
 const [log,setLog]=useState<string[]>([]);
 const [busy,setBusy]=useState(false);
 const client=createPublicClient({transport:http(RPC)});
 const note=(line:string)=>setLog(prev=>[...prev,line]);

 async function guard(fn:()=>Promise<void>){
  setBusy(true);
  try{await fn();}catch(e){note('ERROR: '+(e instanceof Error?e.message:String(e)));}
  finally{setBusy(false);}
 }
 function need(condition:boolean,message:string){if(!condition)throw Error(message);}
 function config(){
  need(isAddress(token)&&isAddress(approval)&&isAddress(ids),'Fill token, approval and registry contract addresses.');
  need(!!actor,'Choose the acting account.');
  return {token:token as Addr,approval:approval as Addr,ids:ids as Addr,actor:actor as Addr};
 }
 async function connect(){
  const id=await rpc('eth_chainId',[]) as string;
  if(parseInt(id,16)!==expectedChainId)throw Error('Configured chain mismatch: '+parseInt(id,16));
  const list=await connectionAccounts();
  setAccounts(list);
  if(list.length&&!actor)setActor(list[0]);
  setChain(expectedChainId+' @ block '+parseInt(await rpc('eth_blockNumber',[]) as string,16));
 }
 async function attest(){await guard(async()=>{
  const c=config();need(isAddress(holder),'Invalid holder address.');
  const ref=await refFrom(refText);
  const {hash,block}=await sendTx(c.actor,c.ids,encodeFunctionData({abi:idsAbi,functionName:'attest',
   args:[holder as Addr,840,BigInt(4102444800),ref as `0x${string}`]}));
  note(`attest ${holder} tx=${hash} block=${block}`);
 });}
 async function propose(){await guard(async()=>{
  const c=config();need(isAddress(holder),'Invalid investor address.');
  const ref=await refFrom(refText);
  const {hash,block}=await sendTx(c.actor,c.approval,encodeFunctionData({abi:approvalAbi,functionName:'propose',
   args:[ref as `0x${string}`,holder as Addr,BigInt(units)]}));
  note(`propose ${units} units for ${holder} tx=${hash} block=${block}`);
 });}
 async function execute(){await guard(async()=>{
  const c=config();const ref=await refFrom(refText);
  const {hash,block}=await sendTx(c.actor,c.approval,encodeFunctionData({abi:approvalAbi,functionName:'execute',
   args:[ref as `0x${string}`]}));
  note(`execute issuance tx=${hash} block=${block}`);
 });}
 async function move(){await guard(async()=>{
  const c=config();need(isAddress(target),'Invalid recipient.');
  const {hash,block}=await sendTx(c.actor,c.token,encodeFunctionData({abi:tokenAbi,functionName:'transfer',
   args:[target as Addr,BigInt(amount)]}));
  note(`transfer ${amount} to ${target} tx=${hash} block=${block}`);
 });}
 async function request(){await guard(async()=>{
  const c=config();const ref=await refFrom(refText);
  const manager=await client.readContract({address:c.approval,abi:approvalAbi,functionName:'manager'});
  const {hash,block}=await sendTx(c.actor,manager,encodeFunctionData({abi:managerAbi,functionName:'requestRedemption',
   args:[ref as `0x${string}`,BigInt(units)]}));
  note(`request redemption ${units} units tx=${hash} block=${block}`);
 });}
 async function approveRedemption(){await guard(async()=>{
  const c=config();need(isAddress(holder),'Invalid holder address.');
  const ref=await refFrom(refText);
  const {hash,block}=await sendTx(c.actor,c.approval,encodeFunctionData({abi:approvalAbi,functionName:'approveRedemption',
   args:[holder as Addr,ref as `0x${string}`]}));
  note(`approve redemption tx=${hash} block=${block}`);
 });}
 async function settle(){await guard(async()=>{
  const c=config();need(isAddress(holder),'Invalid holder address.');
  const ref=await refFrom(refText);
  const manager=await client.readContract({address:c.approval,abi:approvalAbi,functionName:'manager'});
  const [u,status]=await client.readContract({address:manager,abi:managerAbi,functionName:'redemptions',
   args:[holder as Addr,ref as `0x${string}`]});
  need(status===4,`redemption not approved (status ${status})`);
  const receipt={chainId:expectedChainId,currency:'SIM',holder:holder.toLowerCase(),manager:manager.toLowerCase(),
   minorAmount:receiptAmounts(u).minorAmount,paymentId,reference:ref.toLowerCase(),units:receiptAmounts(u).units};
  const canonical=JSON.stringify(receipt);
  const payment=await sha256hex('SIM:'+paymentId);
  const digest=await sha256hex(canonical);
  const {hash,block}=await sendTx(c.actor,c.approval,encodeFunctionData({abi:approvalAbi,functionName:'confirmRedemption',
   args:[holder as Addr,ref as `0x${string}`,payment as `0x${string}`,digest as `0x${string}`]}));
  note(`settle ${u} units payment=${payment} tx=${hash} block=${block}`);
 });}
 async function rejectUnpaid(){await guard(async()=>{
  const c=config();need(isAddress(holder),'Invalid holder address.');
  const ref=await refFrom(refText);
  const {hash,block}=await sendTx(c.actor,c.approval,encodeFunctionData({abi:approvalAbi,functionName:'rejectUnpaidRedemption',
   args:[holder as Addr,ref as `0x${string}`]}));
  note(`reject unpaid redemption tx=${hash} block=${block}`);
 });}
 async function inspect(){await guard(async()=>{
  need(isAddress(token)&&isAddress(holder),'Enter valid token and holder addresses.');
  if(await client.getChainId()!==expectedChainId)throw Error('Configured chain mismatch.');
  setLedger('');
  const block=await client.getBlockNumber();
  const [supply,cap,paused,balance,frozen,reserved]=await Promise.all([
   client.readContract({address:token as Addr,abi:tokenAbi,functionName:'totalSupply',blockNumber:block}),
   client.readContract({address:token as Addr,abi:tokenAbi,functionName:'cap',blockNumber:block}),
   client.readContract({address:token as Addr,abi:tokenAbi,functionName:'paused',blockNumber:block}),
   client.readContract({address:token as Addr,abi:tokenAbi,functionName:'balanceOf',args:[holder as Addr],blockNumber:block}),
   client.readContract({address:token as Addr,abi:tokenAbi,functionName:'frozen',args:[holder as Addr],blockNumber:block}),
   client.readContract({address:token as Addr,abi:tokenAbi,functionName:'reserved',args:[holder as Addr],blockNumber:block})]);
  setLedger(JSON.stringify({block:block.toString(),supply:supply.toString(),cap:cap.toString(),paused,
   balance:balance.toString(),reserved:reserved.toString(),frozen},null,2));
 });}
 const input={display:'block',width:'95%',padding:10};
 const box={border:'1px solid #33505c',padding:16,marginTop:16};
 const btn={padding:10,marginRight:8,marginTop:8,background:'#64d4bc',border:0};
 return <main style={{maxWidth:960,margin:'40px auto',padding:24}}>
  <p style={{color:'#64d4bc'}}>RWA / {expectedChainId === 31337 ? 'LOCAL OPERATIONS' : 'SEPOLIA OPERATIONS'}</p>
  <h1>Permissioned asset console</h1>
  <p style={{color:'#e8bf77'}}>Simulation only. Token ownership does not establish legal title or prove offchain reserves. {expectedChainId === 31337 ? 'Disposable local chain accounts sign transactions.' : 'Your connected wallet signs each transaction on Ethereum Sepolia. Issuer and reviewer require distinct addresses.'}</p>
  <div style={box}>
   <b>1. Chain</b> <span>{chain||'not connected'}</span><br/>
   <button style={btn} disabled={busy} onClick={()=>guard(connect)}>{expectedChainId === 31337 ? 'Connect local chain' : 'Connect Sepolia wallet'}</button>
   {accounts.length>0&&<label>Acting account
    <select style={input} value={actor} onChange={e=>setActor(e.target.value)}>
     {accounts.map(a=><option key={a} value={a}>{a}</option>)}
    </select></label>}
  </div>
  <div style={box}>
   <b>2. Contracts</b>
   <label>Token address<input style={input} value={token} onChange={e=>setToken(e.target.value)}/></label>
   <label>Approval address<input style={input} value={approval} onChange={e=>setApproval(e.target.value)}/></label>
   <label>Identity registry<input style={input} value={ids} onChange={e=>setIds(e.target.value)}/></label>
  </div>
  <div style={box}>
   <b>3. Operations</b>
   <label>Reference label<input style={input} value={refText} onChange={e=>setRefText(e.target.value)}/></label>
   <label>Investor / holder<input style={input} value={holder} onChange={e=>setHolder(e.target.value)}/></label>
   <label>Units<input style={input} value={units} onChange={e=>setUnits(e.target.value)}/></label>
   <label>Transfer recipient<input style={input} value={target} onChange={e=>setTarget(e.target.value)}/></label>
   <label>Transfer amount<input style={input} value={amount} onChange={e=>setAmount(e.target.value)}/></label>
   <label>Simulated payment id<input style={input} value={paymentId} onChange={e=>setPaymentId(e.target.value)}/></label>
   <div>
    <button style={btn} disabled={busy} onClick={attest}>Attest identity (issuer)</button>
    <button style={btn} disabled={busy} onClick={propose}>Propose issuance (issuer)</button>
    <button style={btn} disabled={busy} onClick={execute}>Execute issuance (reviewer)</button>
    <button style={btn} disabled={busy} onClick={move}>Transfer (holder)</button>
    <button style={btn} disabled={busy} onClick={request}>Request redemption (holder)</button>
    <button style={btn} disabled={busy} onClick={approveRedemption}>Approve redemption (issuer)</button>
    <button style={btn} disabled={busy} onClick={settle}>Settle with synthetic receipt (reviewer)</button>
    <button style={btn} disabled={busy} onClick={rejectUnpaid}>Reject unpaid (reviewer)</button>
   </div>
  </div>
  <div style={box}>
   <b>4. Ledger</b>
   <button style={btn} disabled={busy} onClick={inspect}>Inspect holder</button>
   <pre role="status" style={{whiteSpace:'pre-wrap',padding:16,background:'#1c2b36'}}>{ledger||'No readback yet.'}</pre>
  </div>
  <div style={box}>
   <b>5. Receipts</b>
   <pre role="log" style={{whiteSpace:'pre-wrap',padding:16,background:'#1c2b36'}}>{log.join('\n')||'No transactions yet.'}</pre>
  </div>
 </main>;
}
