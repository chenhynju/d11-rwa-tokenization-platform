#!/usr/bin/env python3
"""Exercise the real operator workflow on an owned disposable Anvil, never a public RPC."""
from pathlib import Path
import datetime,json,os,socket,subprocess,time,urllib.request
ROOT=Path(__file__).resolve().parents[1]
port=18861;url=f'http://127.0.0.1:{port}';stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
output=ROOT/'evidence/local-workflow'/stamp;output.mkdir(parents=True,exist_ok=True)
opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
def rpc(method,params):
 req=urllib.request.Request(url,json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),{'Content-Type':'application/json'})
 with opener.open(req,timeout=5) as response:data=json.load(response)
 if 'error' in data:raise RuntimeError(data['error'])
 return data['result']
def cast(*args):return subprocess.check_output(['cast',*map(str,args)],text=True,env=env).strip()
with socket.socket() as probe:probe.bind(('127.0.0.1',port))
env={**os.environ,'ETH_RPC_URL':url,'NO_PROXY':'127.0.0.1,localhost','no_proxy':'127.0.0.1,localhost'}
with (output/'anvil.log').open('w') as log:
 node=subprocess.Popen(['anvil','--host','127.0.0.1','--port',str(port),'--chain-id','31337','--hardfork','cancun','--silent'],stdout=log,stderr=log)
 try:
  for _ in range(100):
   if node.poll() is not None:raise RuntimeError('Owned node exited; refusing another service')
   try:
    if int(rpc('eth_chainId',[]),16)==31337:break
   except Exception:time.sleep(.1)
  else:raise RuntimeError('Owned node not ready')
  accounts=rpc('eth_accounts',[]);env['LOCAL_REVIEWER']=accounts[1]
  with (output/'deployment.log').open('w') as deployment_log:
   subprocess.run(['forge','script','script/Deploy.s.sol:Deploy','--rpc-url',url,'--sender',accounts[0],'--unlocked','--broadcast','--gas-estimate-multiplier','200'],cwd=ROOT,env=env,stdout=deployment_log,stderr=subprocess.STDOUT,check=True)
  run=json.loads((ROOT/'broadcast/Deploy.s.sol/31337/run-latest.json').read_text());contracts={t['contractName']:t['contractAddress'] for t in run['transactions'] if t.get('transactionType')=='CREATE'};contracts['IssuanceManager']=cast('call',contracts['InstitutionalApproval'],'manager()(address)')
  hashes={name:cast('keccak',rpc('eth_getCode',[address,'latest'])) for name,address in contracts.items()}
  fixture={'chainId':31337,'issuer':accounts[0],'reviewer':accounts[1],'contracts':contracts,'runtimeHashes':hashes};file=output/'fixture.json';file.write_text(json.dumps(fixture,indent=2)+'\n')
  for address in [accounts[1],accounts[2]]:rpc('anvil_setBalance',[address,'0x0'])
  result=output/'acceptance.json';command=['python3',str(ROOT/'scripts/public_testnet_smoke.py'),'--unlocked-local','--deployment',str(file),'--evidence',str(result)]
  subprocess.run(command,cwd=ROOT,env=env,check=True)
  proof=json.loads(result.read_text());assert proof['status']=='PASS' and len(proof['steps'])==10 and len(proof['checks'])==5
  # A second invocation must reuse successful receipts, not issue or fund again.
  nonce_before={a:rpc('eth_getTransactionCount',[a,'latest']) for a in accounts[:3]};subprocess.run(command,cwd=ROOT,env=env,check=True);assert {a:rpc('eth_getTransactionCount',[a,'latest']) for a in accounts[:3]}==nonce_before
  probe=subprocess.run(command[:-1]+[str(output/'refuse-existing-market.json')],cwd=ROOT,env=env,capture_output=True,text=True)
  assert probe.returncode!=0 and 'empty fresh deployment' in probe.stderr
  assert {a:rpc('eth_getTransactionCount',[a,'latest']) for a in accounts[:3]}==nonce_before
  pending=json.loads(result.read_text());pending['status']='INJECTED_PENDING_TEST';pending['steps']['confirm-redemption']['status']='PENDING'
  pending_file=output/'pending-confirm-refusal.json';pending_file.write_text(json.dumps(pending,indent=2))
  probe=subprocess.run(command[:-1]+[str(pending_file)],cwd=ROOT,env=env,capture_output=True,text=True)
  assert probe.returncode!=0 and 'Uncertain receipt' in probe.stderr
  assert {a:rpc('eth_getTransactionCount',[a,'latest']) for a in accounts[:3]}==nonce_before
  print('PASS ten local transactions, five rejected calls, ledger, idempotent rerun and preservation of an existing market')
 finally:
  node.terminate()
  try:node.wait(timeout=10)
  except subprocess.TimeoutExpired:node.kill();node.wait()
