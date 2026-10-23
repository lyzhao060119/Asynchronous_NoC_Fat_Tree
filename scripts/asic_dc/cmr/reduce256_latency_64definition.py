"""Re-reduce existing 256 Tail records using the 64 TB window-copy metric."""
import json
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

CODE=r'''
import csv,json,statistics,hashlib
from pathlib import Path
r=Path('/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks')
rows=[]
for d in ['M16_256','Mesh256']:
 for b,load in [('MULTICAST10-AABB',40),('ALL-MULTICAST-AABB',20)]:
  for seed in [202701,202702,202703]:
   stem=f'{b}_n256_s{seed}_m{load}'
   for mode in ['native','repeated']:
    name=stem+('_repeated' if mode=='repeated' else '')
    log=r/'logs'/d/name
    metric=json.loads((log/'metrics.json').read_text());assert metric['valid']
    raw=next(csv.DictReader((r/'results'/d/(name+'.csv')).open()))
    start,end=int(raw['measurement_start_ps']),int(raw['measurement_end_ps'])
    side=json.loads((r/'sidecars'/(stem+'_'+mode+'.json')).read_text())
    packets={p['pkt_seq']:p for p in side['packets']}
    values=[];queue=[];network=[];seen=set();excluded=0
    with (log/'latency.csv').open() as f:
     for tail in csv.DictReader(f):
      seq=int(tail['pkt_seq']);dest=int(tail['port']);p=packets[seq]
      assert (seq,dest) not in seen;seen.add((seq,dest))
      if p['phase']!='measurement':continue
      offer=int(tail['head_offer_ps']);rx=int(tail['tail_egress_req_ps'])
      if not (start<=offer<end and start<=rx<end):excluded+=1;continue
      values.append((rx-offer)/1000)
      req=int(tail['head_inject_req_ps'])
      queue.append((req-offer)/1000);network.append((rx-req)/1000)
    assert len(seen)*5==side['expected_copy_flits']
    assert values
    rows.append(dict(design=d,benchmark=b,load=load,seed=seed,mode=mode,
      mean_window_copy_latency_ns=statistics.mean(values),included_copies=len(values),excluded_measurement_copies=excluded,
      mean_offer_to_head_req_ns=statistics.mean(queue),mean_head_req_to_tail_ns=statistics.mean(network),
      old_last_destination_latency_ns=metric['mean_last_destination_ns'],window_start_ps=start,window_end_ps=end,
      tail_csv_sha256=hashlib.sha256((log/'latency.csv').read_bytes()).hexdigest()))
print('REDUCED_JSON='+json.dumps(rows))
'''
if __name__=='__main__':
 c=connect()
 try:
  t=remote_run(c,"/soft/GNU/python3.12/bin/python3 - <<'PY'\n"+CODE+"\nPY")
  if 'REDUCED_JSON=' not in t:raise RuntimeError(t)
  rows=json.loads(t.split('REDUCED_JSON=',1)[1].splitlines()[0])
  p=Path('results/formal256_native_repeated_latency_64definition_20261022_r1');p.mkdir(exist_ok=True)
  (p/'seed_records.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows,indent=2))
 finally:c.close()
