"""Fetch only small source/launcher evidence for cross-scale metric audit."""
import csv,json,hashlib
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

out=Path('results/metric_scope_audit_20261022');out.mkdir(exist_ok=True)
with Path('results/formal64_all_20261021_r1/scan_results_all_seeds.csv').open() as f:rows=list(csv.DictReader(f))
selected=[r for r in rows if r['design'] in ('PROP_M16','FM64') and r['benchmark'] in ('TOPO-UR','MULTICAST10-AABB','ALL-MULTICAST-AABB') and r['seed']=='202701' and r['load']=='5']
(out/'selected_provenance.json').write_text(json.dumps(selected,indent=2))
roots=sorted({r['source_csv'].split('/results/')[0] for r in selected})
roots+=['/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks']
c=connect()
try:
 for i,root in enumerate(roots):
  command='find '+root+' -maxdepth 3 -type f \\( -name "*.sv" -o -name "*.sh" -o -name "*compile*.log" -o -name "*.py" \\) -printf "%p\\n" | head -n 100'
  listing=remote_run(c,command)
  (out/f'root{i}_listing.txt').write_text(root+'\n'+listing)
  print(root,listing)
  s=c.open_sftp()
  wanted=[line for line in listing.splitlines() if line.startswith(root+'/') and
          ('/src/' in line or line.endswith('.sh') or line.endswith('/compile.log')) and '/diagnostics/' not in line]
  for remote in wanted:
   try:
    if s.stat(remote).st_size>2000000:continue
    local=out/f'root{i}'/remote[len(root)+1:];local.parent.mkdir(parents=True,exist_ok=True)
    s.get(remote,str(local))
   except OSError as e:print('UNAVAILABLE',remote,str(e))
  s.close()
finally:c.close()
