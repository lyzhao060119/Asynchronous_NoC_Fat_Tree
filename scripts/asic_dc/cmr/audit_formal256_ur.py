"""Read-only audit of the frozen 180-point UR campaign."""
import json
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

CODE = r'''
import json,csv,re
from pathlib import Path
r=Path('/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks')
loads=[5,10,20]+list(range(40,501,20))+[600,700,800]
out={}
for d in ['Mesh256','M16_256']:
 a=json.loads((r/'work'/d/'annotation_status.json').read_text())
 rows=[]; failures=[]
 for s in [202701,202702,202703]:
  for l in loads:
   stem=f'TOPO-UR_n256_s{s}_m{l}'
   p=r/'logs'/d/stem
   try:
    m=json.loads((p/'metrics.json').read_text())
    raw=next(csv.DictReader((r/'results'/d/(stem+'.csv')).open()))
    log=(p/'run.log').read_text(errors='replace')
    checks=dict(metric_valid=m['valid'],tb_pass='TB_RESULT PASS' in log,
      raw_pass=raw['pass_fail']=='PASS',counts=int(raw['injected_flits'])==int(raw['delivered_flits'])==55000,
      no_missing=int(raw['missing_expected_flits'])==0,no_unexpected=int(raw['unexpected_flits'])==0,
      no_timeout=int(raw['timeout_hit'])==0,all_originals=m['completed_originals']==10000,
      clean_runtime=not bool(re.search(r'Timing violation|TB_X_FAIL|TB_FATAL|Fatal:|\$fatal',log,re.I)),
      annotation=a['errors']==0 and a['missing_timing_checks']==0 and not a['negative_separate_checks_limited'])
    row=dict(seed=s,load=l,passed=all(checks.values()),checks=checks,delivery_fraction=m['delivery_fraction'],latency_ns=m['mean_last_destination_ns'])
    rows.append(row)
    if not row['passed']: failures.append(row)
   except Exception as e: failures.append(dict(seed=s,load=l,error=str(e)))
 out[d]=dict(expected=90,found=len(rows),passed=sum(x['passed'] for x in rows),failures=failures,
   curve_eligible_points=sum(all(x['passed'] and x['delivery_fraction']>=.99 for x in rows if x['load']==l) and sum(x['load']==l for x in rows)==3 for l in loads),rows=rows)
print('UR_AUDIT_JSON='+json.dumps(out))
'''

if __name__ == '__main__':
    c=connect()
    try:
        text=remote_run(c,"/soft/GNU/python3.12/bin/python3 - <<'PY'\n"+CODE+"\nPY")
        payload=text.split('UR_AUDIT_JSON=',1)[1].splitlines()[0]
        data=json.loads(payload)
        target=Path('results/formal256_20261019_r3_checks/ur_audit.json')
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(json.dumps(data,indent=2))
        for d,v in data.items():
            print(d,json.dumps({k:x for k,x in v.items() if k!='rows'}))
        print('SAVED',target)
    finally:
        c.close()
