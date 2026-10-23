"""Finalize the audited remote campaign and retrieve only small evidence."""
import json
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

CODE=r'''
import json,csv,re,hashlib,importlib.util
from pathlib import Path
r=Path('/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks')
s=importlib.util.spec_from_file_location('campaign',r/'formal256_campaign.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
audit=json.loads((r/'manifests/full_reduction_audit.json').read_text())
remaining=[]
for failure in audit['failures']:
 d,b,seed,load,mode=[failure[k] for k in ('design','benchmark','seed','load','mode')]
 row=m.collect_case(r,d,f'{b}_n256_s{seed}_m{load}',mode)
 if not row['valid']:remaining.append(row);continue
 group=audit['groups'][f'{d}/{b}/{mode}']
 if 'error' in failure:group['measured']+=1
 else:group['invalid']-=1
 group['valid']+=1
audit['failures']=remaining
assert not remaining and sum(v['valid'] for v in audit['groups'].values())==552
# Independently inspect all formal runtime logs, including file I/O failures.
runtime_bad=[];bindings=[]
for path in (r/'logs').glob('*/*/metrics.json'):
 row=json.loads(path.read_text())
 if row.get('benchmark') not in m.BENCHMARKS or row.get('seed') not in m.SEEDS:continue
 if not re.fullmatch(r'(TOPO-UR|MULTICAST10-AABB|ALL-MULTICAST-AABB)_n256_s20270[123]_m\d+(_repeated)?',path.parent.name):continue
 log=(path.parent/'run.log').read_text(errors='replace')
 if re.search(r'Timing violation|TB_X_FAIL|TB_FATAL|Error-\[|Fatal:|Disk quota exceeded',log,re.I) or 'TB_RESULT PASS' not in log:runtime_bad.append(str(path))
 bindings.append(dict(path=str(path),metrics_sha256=m.sha(path),log_sha256=m.sha(path.parent/'run.log')))
assert len(bindings)==552,(len(bindings),runtime_bad)
assert not runtime_bad,runtime_bad
audit['runtime_log_audit']=dict(checked=len(bindings),failures=runtime_bad)
m.save(r/'manifests/full_reduction_audit.json',audit)
m.save(r/'manifests/result_hashes.json',bindings)
# Derive area CSV from the frozen DC report, not an empty design attribute.
for d in m.DESIGNS:
 p=r/'area'/d
 old=next(csv.DictReader((p/'area.csv').open()))
 a=re.search(r'Total cell area:\s+([0-9]+\.[0-9]+)',(p/'area.rpt').read_text()).group(1)
 assert float(a)>0 and int(old['leaf_cells'])>0
 old['cell_area_um2']=a
 with (p/'area.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(old));w.writeheader();w.writerow(old)
spec=importlib.util.spec_from_file_location('control',r/'formal256_control.py');control=importlib.util.module_from_spec(spec);spec.loader.exec_module(control);control.report(r,m)
print('FORMAL256_FINAL_AUDIT_PASS',json.dumps(audit))
'''
if __name__=='__main__':
 c=connect()
 try:
  output=remote_run(c,"/soft/GNU/python3.12/bin/python3 - <<'PY'\n"+CODE+"\nPY")
  print(output)
  if 'FORMAL256_FINAL_AUDIT_PASS' not in output:raise RuntimeError('final audit failed')
  r='/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks'
  files=['manifests/full_reduction_audit.json','manifests/result_hashes.json','summary/raw_metrics.csv','summary/three_seed_means.csv','summary/coverage.json','area/Mesh256/area.csv','area/M16_256/area.csv']
  s=c.open_sftp()
  for name in files:
   assert s.stat(r+'/'+name).st_size<10000000
   p=Path('results/formal256_20261019_r3_checks')/name;p.parent.mkdir(parents=True,exist_ok=True);s.get(r+'/'+name,str(p))
  s.close()
 finally:c.close()
