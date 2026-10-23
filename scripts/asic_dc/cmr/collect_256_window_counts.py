"""Fetch only fixed-window counters required for a cross-scale re-reduction."""
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run
CODE=r'''
import csv,io,json
from pathlib import Path
r=Path('/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks')
rows=[]
for d in ['Mesh256','M16_256']:
 for b in ['TOPO-UR','MULTICAST10-AABB','ALL-MULTICAST-AABB']:
  for s in [202701,202702,202703]:
   for l in [5,10,20]+list(range(40,501,20))+[600,700,800]:
    p=r/'results'/d/f'{b}_n256_s{s}_m{l}.csv'
    raw=next(csv.DictReader(p.open()))
    row={k:raw[k] for k in ['measurement_start_ps','measurement_end_ps','measurement_offered_flits','measurement_delivered_flits','offered_mflit_port_s','delivered_mflit_port_s','pass_fail','injected_flits','delivered_flits','missing_expected_flits','unexpected_flits','timeout_hit']}
    row.update(design=d,benchmark=b,seed=s,load=l)
    rows.append(row)
buf=io.StringIO();w=csv.DictWriter(buf,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
print('COUNTERS_JSON='+json.dumps(buf.getvalue()))
'''
if __name__=='__main__':
 import json
 c=connect()
 try:
  t=remote_run(c,"/soft/GNU/python3.12/bin/python3 - <<'PY'\n"+CODE+"\nPY")
  data=json.loads(t.split('COUNTERS_JSON=',1)[1].splitlines()[0])
  p=Path('results/metric_scope_audit_20261022/window_counts_256.csv');p.write_text(data)
  print('COUNTERS_DOWNLOADED',p,len(data))
 finally:c.close()
