"""Security regression for explicit synthetic receipt network authorization."""
import importlib.util,json,os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('receipt_policy',Path(__file__).with_name('check-redemption-receipt.py'));policy=importlib.util.module_from_spec(spec);spec.loader.exec_module(policy)
class ReceiptPolicyTest(unittest.TestCase):
 def check_receipt(self,network,override=None,changes=None,status=4):
  manager='0x'+'11'*20;body={'chainId':network,'manager':manager,'holder':'0x'+'22'*20,'reference':'0x'+'33'*32,'units':1,'minorAmount':100,'currency':'SIM','paymentId':'synthetic-test'};body.update(changes or {})
  def rpc(*args):return str(network) if args[0]=='chain-id' else '0x'+f'{1:064x}{status:064x}{0:064x}'
  env={} if override is None else {'D11_RECEIPT_CHAIN_ID':str(override)}
  with tempfile.TemporaryDirectory() as directory,patch.dict(os.environ,env,clear=True),patch.object(policy,'cast',side_effect=rpc):
   file=Path(directory)/'receipt.json';file.write_text(json.dumps(body));return policy.validate(manager,file)
 def test_local_default(self):self.assertEqual(len(self.check_receipt(31337).split()),2)
 def test_base_requires_explicit_opt_in(self):
  with self.assertRaisesRegex(ValueError,'network'):self.check_receipt(84532)
  self.assertEqual(len(self.check_receipt(84532,84532).split()),2)
 def test_mainnet_is_never_allowed(self):
  with self.assertRaisesRegex(ValueError,'unsupported'):self.check_receipt(1,1)
 def test_receipt_chain_must_match_rpc(self):
  with self.assertRaisesRegex(ValueError,'network'):self.check_receipt(84532,84532,{'chainId':11155111})
 def test_boolean_units_are_not_integer_units(self):
  with self.assertRaises(ValueError):self.check_receipt(84532,84532,{'units':True})
 def test_approved_state_is_required(self):
  with self.assertRaises(ValueError):self.check_receipt(84532,84532,status=1)
 def test_real_currency_is_never_accepted(self):
  with self.assertRaises(ValueError):self.check_receipt(84532,84532,{'currency':'USD'})
if __name__=='__main__':unittest.main()
