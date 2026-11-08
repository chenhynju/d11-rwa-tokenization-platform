#!/usr/bin/env python3
"""Measure the same production source without IR source-map ambiguity; do not change production config."""
from pathlib import Path
import subprocess,tempfile,shutil,json,hashlib
root=Path(__file__).resolve().parents[1];out=root/'evidence';out.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='d11-coverage-') as td:
 work=Path(td)
 for name in ['src','test','script']:shutil.copytree(root/name,work/name)
 (work/'foundry.toml').write_text((root/'foundry.toml').read_text().replace('via_ir = true','via_ir = false'))
 command=['forge','coverage','--fuzz-seed','0x20261108','--report','summary','--report','lcov']
 result=subprocess.run(command,cwd=work)
 if result.returncode:raise SystemExit(result.returncode)
 shutil.copy2(work/'lcov.info',out/'coverage-non-ir.lcov')
 metrics=[]
 for record in (work/'lcov.info').read_text().split('end_of_record'):
  values={k:v for line in record.splitlines() if ':' in line for k,v in [line.split(':',1)] if k in ['SF','LF','LH','BRF','BRH']}
  if values.get('SF','').startswith('src/'):metrics.append(values)
 passed=bool(metrics) and all(int(row['BRF'])==0 or int(row['BRH'])*100>=int(row['BRF'])*90 for row in metrics)
 report={'status':'PASS' if passed else 'FAIL','compiler':'0.8.38','instrumentation':'non-IR coverage; production via-IR configuration remains unchanged','command':command,'metrics':metrics,'sourceHashes':{str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in (root/'src').glob('*.sol')}}
 (out/'coverage-current.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));raise SystemExit(0 if passed else 1)
