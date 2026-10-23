"""Preserve the quota-failed evidence and submit exactly one rerun."""
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

CODE=r'''
import os,json,subprocess,re
from pathlib import Path
r=Path('/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks')
ledger=r/'manifests/quota_retry.json'
if ledger.exists():
 print('ALREADY_SUBMITTED',ledger.read_text());raise SystemExit(0)
stem='ALL-MULTICAST-AABB_n256_s202703_m20'
p=r/'logs/Mesh256'/(stem+'_repeated')
assert 'Disk quota exceeded' in (p/'run.log').read_text()
probe=r/'manifests/quota_probe_16mb.tmp'
try:
 with probe.open('xb') as f:
  for _ in range(16):f.write(b'Q'*1048576)
  f.flush();os.fsync(f.fileno())
finally:
 if probe.exists():probe.unlink()
old=p.with_name(p.name+'_failed_quota_original')
assert not old.exists()
p.rename(old)
raw=r/'results/Mesh256'/(stem+'_repeated.csv')
raw.rename(old/'raw_result.csv')
cmd=f'env FORMAL256_ROOT={r} bash {r}/run_formal256.sh Mesh256 run {stem} repeated'
out=subprocess.check_output(['bsub','-q','normal','-n','1','-J','f256_quota_retry','-o',str(r/'jobs/quota_retry.log'),'-e',str(r/'jobs/quota_retry.err'),cmd],text=True)
j=re.search(r'Job <(\d+)>',out)
assert j,out
data=dict(job_id=j[1],command=cmd,preserved=str(old),reason='latency file empty after quota error')
ledger.write_text(json.dumps(data,indent=2));print('RETRY_SUBMITTED',json.dumps(data))
'''
if __name__=='__main__':
 c=connect()
 try:print(remote_run(c,"/soft/GNU/python3.12/bin/python3 - <<'PY'\n"+CODE+"\nPY"))
 finally:c.close()
