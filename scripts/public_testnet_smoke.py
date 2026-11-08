#!/usr/bin/env python3
"""Synthetic RWA lifecycle. Only Base Sepolia or explicitly unlocked loopback Anvil.

Persist an intent before every transaction; stop on uncertain submission rather
than signing a replacement. Keys/passwords never enter the output or CLI argv.
"""
import argparse,datetime,fcntl,hashlib,json,os,subprocess,time,urllib.request
from pathlib import Path
from urllib.parse import urlparse

ROOT=Path(__file__).resolve().parents[1]

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--deployment',type=Path,default=ROOT/'deployments/base-sepolia-20261108.json')
 parser.add_argument('--evidence',type=Path,default=ROOT/'evidence/base-public-smoke-20261108.json')
 parser.add_argument('--unlocked-local',action='store_true')
 args=parser.parse_args();deployment=json.loads(args.deployment.read_text());chain=deployment['chainId']
 url=os.environ.get('ETH_RPC_URL','https://base-sepolia.gateway.tenderly.co');endpoint=urlparse(url)
 if chain not in {31337,84532}:raise RuntimeError('Mainnet and unsupported networks are forbidden')
 if args.unlocked_local and (chain!=31337 or endpoint.scheme!='http' or endpoint.hostname not in {'127.0.0.1','localhost'}):raise RuntimeError('Unlocked signing requires loopback Anvil')
 if chain==31337 and not args.unlocked_local:raise RuntimeError('Local smoke requires explicit unlocked-local mode')
 if chain==84532 and (endpoint.scheme!='https' or endpoint.username or endpoint.password):raise RuntimeError('Public smoke requires an HTTPS RPC')
 os.environ['ETH_RPC_URL']=url
 if chain==31337:
  os.environ['NO_PROXY']=','.join(filter(None,[os.environ.get('NO_PROXY',''),'127.0.0.1','localhost']));os.environ['no_proxy']=os.environ['NO_PROXY']
 opener=urllib.request.build_opener(urllib.request.ProxyHandler({})) if chain==31337 else urllib.request.build_opener()
 def rpc(method,params):
  request=urllib.request.Request(url,json.dumps({'jsonrpc':'2.0','id':1,'method':method,'params':params}).encode(),{'Content-Type':'application/json'})
  with opener.open(request,timeout=30) as response:value=json.load(response)
  if 'error' in value:raise RuntimeError(json.dumps(value['error']))
  return value['result']
 def cast(*parts):return subprocess.check_output(['cast',*map(str,parts)],text=True).strip()
 def data(signature,*values):return cast('calldata',signature,*values)
 def call(target,signature,*values,actor=None):
  tx={'to':target,'data':data(signature,*values)}
  if actor:tx['from']=actor
  return rpc('eth_call',[tx,'latest'])
 def integer(target,signature,*values):return int(call(target,signature,*values),16)
 if int(rpc('eth_chainId',[]),16)!=chain:raise RuntimeError('RPC chain mismatch')
 c=deployment['contracts'];issuer=deployment['issuer'];reviewer=deployment['reviewer']
 if chain==31337:holder=rpc('eth_accounts',[])[2]
 else:holder=json.loads((ROOT/'deployments/base-sepolia-holder.json').read_text())['holder']
 if len({x.lower() for x in [issuer,reviewer,holder]})!=3:raise RuntimeError('Three distinct role addresses required')
 signers={}
 if not args.unlocked_local:
  home=Path.home();signers={'issuer':(home/'.foundry/keystores/w07-legacy-deployer',home/'.config/w07/legacy-deployer.password'),'reviewer':(home/'.foundry/keystores/d11-rwa-reviewer.json',home/'.config/d11/reviewer.password'),'holder':(home/'.foundry/keystores/d11-rwa-holder.json',home/'.config/d11/holder.password')}
  for role,(key,password) in signers.items():
   for file in [key,password]:
    if not file.is_file() or file.stat().st_mode&0o077:raise RuntimeError('Signer files must exist with private permissions')
   actual=cast('wallet','address','--keystore',key,'--password-file',password)
   if actual.lower()!=locals()[role].lower():raise RuntimeError('Signer identity mismatch')
 for name,expected in deployment['runtimeHashes'].items():
  code=rpc('eth_getCode',[c[name],'latest'])
  if cast('keccak',code)!=expected:raise RuntimeError('Runtime code mismatch: '+name)
 lock_dir=Path.home()/'.cache/web3-portfolio';lock_dir.mkdir(parents=True,exist_ok=True)
 lock_fd=os.open(lock_dir/f'd11-smoke-{chain}-{issuer.lower()}.lock',os.O_CREAT|os.O_RDWR,0o600)
 fcntl.flock(lock_fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
 state=json.loads(args.evidence.read_text()) if args.evidence.exists() else {'chainId':chain,'contracts':c,'roles':{'issuer':issuer,'reviewer':reviewer,'holder':holder},'steps':{},'checks':[]}
 if state['chainId']!=chain or state['contracts']!=c or state['roles']['holder'].lower()!=holder.lower():raise RuntimeError('Evidence belongs to a different deployment')
 if not state['steps'] and integer(c['PermissionedToken'],'totalSupply()')!=0:raise RuntimeError('Demo requires an empty fresh deployment; existing market state is preserved')
 source_hash=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
 if state.get('workflowSourceSha256',source_hash)!=source_hash:raise RuntimeError('Frozen workflow source changed; review before resuming')
 state.setdefault('workflowSourceSha256',source_hash)
 state.setdefault('gitHeadAtRun',subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip())
 args.evidence.parent.mkdir(parents=True,exist_ok=True)
 def save():
  temporary=args.evidence.with_name(args.evidence.name+'.pending-'+str(os.getpid()))
  with temporary.open('w') as stream:
   stream.write(json.dumps(state,indent=2)+'\n');stream.flush();os.fsync(stream.fileno())
  os.replace(temporary,args.evidence)
  directory_fd=os.open(args.evidence.parent,os.O_RDONLY|os.O_DIRECTORY)
  try:os.fsync(directory_fd)
  finally:os.close(directory_fd)
 def send(label,role,target,signature=None,values=(),value=0):
  prior=state['steps'].get(label)
  if prior:
   if prior['status']!='PASS':raise RuntimeError('Uncertain prior transaction: inspect saved nonce/receipt before any retry')
   receipt=rpc('eth_getTransactionReceipt',[prior['receipt']['transactionHash']])
   if not receipt or receipt['status']!='0x1':raise RuntimeError('Previously recorded receipt no longer succeeds')
   return
  actor={'issuer':issuer,'reviewer':reviewer,'holder':holder}[role]
  latest=int(rpc('eth_getTransactionCount',[actor,'latest']),16);pending=int(rpc('eth_getTransactionCount',[actor,'pending']),16)
  if latest!=pending:raise RuntimeError('Unresolved pending nonce; stop before signing')
  payload=data(signature,*values) if signature else '0x'
  state['steps'][label]={'status':'PENDING','from':actor,'to':target,'nonce':pending,'valueWei':str(value),'dataHash':hashlib.sha256(bytes.fromhex(payload[2:])).hexdigest()};save()
  command=['cast','send',target,'--from',actor,'--nonce',str(pending),'--json']
  if signature:command += [signature,*map(str,values)]
  if value:command += ['--value',str(value)]
  if args.unlocked_local:command+=['--unlocked']
  else:
   key,password=signers[role];command+=['--keystore',str(key),'--password-file',str(password),'--gas-price','20000000','--priority-gas-price','1000000']
  result=subprocess.run(command,capture_output=True,text=True,timeout=120)
  if result.returncode:
   state['steps'][label]['failure']=result.stderr[-2000:];save();raise RuntimeError('Submission failed or uncertain; no automatic resend: '+label)
  receipt=json.loads(result.stdout)
  if receipt.get('status')!='0x1':state['steps'][label]['receipt']=receipt;save();raise RuntimeError('Onchain transaction failed: '+label)
  state['steps'][label].update({'status':'PASS','receipt':receipt});save();print('PASS '+label,flush=True)
 def rejected(label,target,signature,*values,actor):
  if label in state['checks']:return
  try:call(target,signature,*values,actor=actor)
  except RuntimeError as error:
   if 'revert' not in str(error).lower():raise
   if label not in state['checks']:
    state['checks'].append(label);state.setdefault('rejectionEvidence',{})[label]={'block':rpc('eth_blockNumber',[]),'from':actor,'to':target,'data':data(signature,*values),'error':str(error)};save()
   print('PASS rejected '+label,flush=True);return
  raise RuntimeError('Forbidden action unexpectedly succeeded in simulation: '+label)
 target_funds=10**16 if chain==31337 else 10**14
 for role,address in [('reviewer',reviewer),('holder',holder)]:
  if 'fund-'+role in state['steps']:send('fund-'+role,'issuer',address)
  elif int(rpc('eth_getBalance',[address,'latest']),16)<target_funds//2:send('fund-'+role,'issuer',address,value=target_funds)
 latest_block=rpc('eth_getBlockByNumber',['latest',False]);state.setdefault('identityExpiry',int(latest_block['timestamp'],16)+30*86400);save()
 identity=cast('keccak','d11-base-smoke-20261108-identity');issue=cast('keccak','d11-base-smoke-20261108-issuance');redeem=cast('keccak','d11-base-smoke-20261108-redemption')
 for role,address in [('holder',holder),('issuer',issuer)]:send('attest-'+role,'issuer',c['IdentityRegistry'],'attest(address,uint16,uint64,bytes32)',(address,840,state['identityExpiry'],identity))
 send('propose-issuance','issuer',c['InstitutionalApproval'],'propose(bytes32,address,uint256)',(issue,holder,400))
 rejected('issuer-cannot-self-approve',c['InstitutionalApproval'],'execute(bytes32)',issue,actor=issuer)
 send('reviewer-execute','reviewer',c['InstitutionalApproval'],'execute(bytes32)',(issue,))
 send('holder-transfer','holder',c['PermissionedToken'],'transfer(address,uint256)',(issuer,150))
 send('request-redemption','holder',c['IssuanceManager'],'requestRedemption(bytes32,uint256)',(redeem,200))
 if 'confirm-redemption' not in state['steps']:
  rejected('reserved-shares-cannot-be-spent',c['PermissionedToken'],'transfer(address,uint256)',issuer,51,actor=holder)
 send('approve-redemption','issuer',c['InstitutionalApproval'],'approveRedemption(address,bytes32)',(holder,redeem))
 if 'confirm-redemption' not in state['steps']:rejected('approved-redemption-cannot-be-cancelled',c['IssuanceManager'],'cancelRedemption(bytes32)',redeem,actor=holder)
 receipt={'chainId':chain,'manager':c['IssuanceManager'].lower(),'holder':holder.lower(),'reference':redeem,'units':200,'minorAmount':20000,'currency':'SIM','paymentId':'d11-base-synthetic-20261108'}
 receipt_file=args.evidence.with_suffix('.receipt.json');receipt_file.write_text(json.dumps(receipt,indent=2)+'\n')
 if 'confirm-redemption' not in state['steps']:
  os.environ['D11_RECEIPT_CHAIN_ID']=str(chain)
  payment,digest=subprocess.check_output(['python3',str(ROOT/'scripts/check-redemption-receipt.py'),c['IssuanceManager'].lower(),str(receipt_file)],text=True).strip().split()
  rejected('issuer-cannot-confirm-payment',c['InstitutionalApproval'],'confirmRedemption(address,bytes32,bytes32,bytes32)',holder,redeem,payment,digest,actor=issuer)
  send('confirm-redemption','reviewer',c['InstitutionalApproval'],'confirmRedemption(address,bytes32,bytes32,bytes32)',(holder,redeem,payment,digest))
 payment='0x'+hashlib.sha256(('SIM:'+receipt['paymentId']).encode()).hexdigest();digest='0x'+hashlib.sha256(json.dumps(receipt,sort_keys=True,separators=(',',':')).encode()).hexdigest()
 rejected('payment-replay-rejected',c['InstitutionalApproval'],'confirmRedemption(address,bytes32,bytes32,bytes32)',holder,redeem,payment,digest,actor=reviewer)
 balances={'holder':integer(c['PermissionedToken'],'balanceOf(address)',holder),'issuer':integer(c['PermissionedToken'],'balanceOf(address)',issuer),'reserved':integer(c['PermissionedToken'],'reserved(address)',holder),'supply':integer(c['PermissionedToken'],'totalSupply()')}
 if balances!={'holder':50,'issuer':150,'reserved':0,'supply':200}:raise RuntimeError('Final ledger does not reconcile: '+str(balances))
 for step in state['steps'].values():
  if step['status']!='PASS':raise RuntimeError('Uncertain receipt must be reconciled before acceptance')
  observed=rpc('eth_getTransactionReceipt',[step['receipt']['transactionHash']])
  if not observed or observed['status']!='0x1':raise RuntimeError('Acceptance requires every recorded transaction receipt')
 state['acceptanceObservedAtUtc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
 state['acceptanceBlock']=rpc('eth_blockNumber',[])
 state.update({'status':'PASS','finalLedger':balances,'syntheticOnly':True,'independentHumanCustody':'NOT_VERIFIED'});save();print('PASS final register reconciliation '+json.dumps(balances),flush=True)
if __name__=='__main__':main()
