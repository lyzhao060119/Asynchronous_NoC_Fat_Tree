"""Re-reduce every formal result remotely; download only the audit summary."""
import json
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

CODE = r'''
import importlib.util,json,traceback
from pathlib import Path
r=Path('/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks')
s=importlib.util.spec_from_file_location('campaign',r/'formal256_campaign.py')
m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
out={}; bad=[]
jobs=[]
for d in m.DESIGNS:
 for b in m.BENCHMARKS:
  for seed in m.SEEDS:
   for load in m.LOADS: jobs.append((d,b,seed,load,'native'))
for j in json.loads((r/'manifests/repeated_jobs.json').read_text()):
 jobs.append((j['design'],j['benchmark'],j['seed'],j['load'],'repeated'))
for d,b,seed,load,mode in jobs:
 key=f'{d}/{b}/{mode}'
 v=out.setdefault(key,dict(expected=0,measured=0,valid=0,invalid=0))
 v['expected']+=1
 stem=f'{b}_n256_s{seed}_m{load}'
 try:
  row=m.collect_case(r,d,stem,mode)
  v['measured']+=1;v['valid']+=int(row['valid']);v['invalid']+=int(not row['valid'])
  if not row['valid']:bad.append(row)
 except Exception as e:bad.append(dict(design=d,benchmark=b,seed=seed,load=load,mode=mode,error=str(e)))
result=dict(groups=out,failures=bad,expected=len(jobs))
(r/'manifests/full_reduction_audit.json').write_text(json.dumps(result,indent=2))
print('AUDIT_JSON='+json.dumps(result))
'''
if __name__=='__main__':
 c=connect()
 try:
  output=remote_run(c,"/soft/GNU/python3.12/bin/python3 - <<'PY'\n"+CODE+"\nPY")
  data=json.loads(output.split('AUDIT_JSON=',1)[1].splitlines()[0])
  p=Path('results/formal256_20261019_r3_checks/full_reduction_audit.json')
  p.write_text(json.dumps(data,indent=2))
  print(json.dumps(data,indent=2))
 finally:c.close()
